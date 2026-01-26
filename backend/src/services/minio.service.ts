import * as Minio from 'minio';
import logger from '../utils/logger.js';
import fs from 'node:fs';
import path from 'node:path';

// MinIO конфигурация из переменных окружения
const MINIO_ENDPOINT = process.env.MINIO_ENDPOINT || 'localhost';
const MINIO_PORT = parseInt(process.env.MINIO_PORT || '9000', 10);
const MINIO_USE_SSL = process.env.MINIO_USE_SSL === 'true';
const MINIO_ACCESS_KEY = process.env.MINIO_ACCESS_KEY || 'andexevents';
const MINIO_SECRET_KEY = process.env.MINIO_SECRET_KEY || 'andexevents_minio_secret';

// Публичный URL для доступа к файлам (для клиентов)
const MINIO_PUBLIC_URL = process.env.MINIO_PUBLIC_URL || `http://localhost:9000`;

// Поддерживаемые бакеты
export const BUCKETS = {
    AVATARS: 'avatars',
    EVENTS: 'events',
    MEDIA: 'media',
} as const;

export type BucketName = typeof BUCKETS[keyof typeof BUCKETS];

class MinioService {
    private client: Minio.Client;
    private initialized: boolean = false;

    constructor() {
        this.client = new Minio.Client({
            endPoint: MINIO_ENDPOINT,
            port: MINIO_PORT,
            useSSL: MINIO_USE_SSL,
            accessKey: MINIO_ACCESS_KEY,
            secretKey: MINIO_SECRET_KEY,
        });
    }

    /**
     * Инициализация сервиса - проверка подключения и создание бакетов
     */
    async initialize(): Promise<void> {
        if (this.initialized) return;

        try {
            logger.info('[MinIO] Подключение к MinIO...', {
                endpoint: MINIO_ENDPOINT,
                port: MINIO_PORT,
                useSSL: MINIO_USE_SSL,
            });

            // Проверяем подключение, пытаясь получить список бакетов
            const buckets = await this.client.listBuckets();
            logger.info(`[MinIO] Подключено. Существующие бакеты: ${buckets.map(b => b.name).join(', ') || 'нет'}`);

            // Создаём необходимые бакеты если их нет
            for (const bucketName of Object.values(BUCKETS)) {
                await this.ensureBucket(bucketName);
            }

            this.initialized = true;
            logger.info('[MinIO] ✅ Сервис инициализирован успешно');
        } catch (error: any) {
            logger.error('[MinIO] ❌ Ошибка инициализации:', { error: error.message });
            throw error;
        }
    }

    /**
     * Создать бакет если не существует
     */
    private async ensureBucket(bucketName: string): Promise<void> {
        try {
            const exists = await this.client.bucketExists(bucketName);
            if (!exists) {
                await this.client.makeBucket(bucketName);
                logger.info(`[MinIO] Создан бакет: ${bucketName}`);

                // Устанавливаем публичную политику для чтения (avatars и events)
                if (bucketName === BUCKETS.AVATARS || bucketName === BUCKETS.EVENTS) {
                    await this.setBucketPublicReadPolicy(bucketName);
                }
            }
        } catch (error: any) {
            logger.error(`[MinIO] Ошибка создания бакета ${bucketName}:`, { error: error.message });
            throw error;
        }
    }

    /**
     * Установить публичную политику чтения для бакета
     */
    private async setBucketPublicReadPolicy(bucketName: string): Promise<void> {
        const policy = {
            Version: '2012-10-17',
            Statement: [
                {
                    Effect: 'Allow',
                    Principal: { AWS: ['*'] },
                    Action: ['s3:GetObject'],
                    Resource: [`arn:aws:s3:::${bucketName}/*`],
                },
            ],
        };

        await this.client.setBucketPolicy(bucketName, JSON.stringify(policy));
        logger.info(`[MinIO] Установлена публичная политика для бакета: ${bucketName}`);
    }

    /**
     * Загрузить файл в MinIO
     */
    async uploadFile(
        bucketName: BucketName,
        objectName: string,
        filePath: string,
        contentType?: string
    ): Promise<string> {
        try {
            // Определяем content-type
            const metaData = contentType ? { 'Content-Type': contentType } : {};

            // Получаем размер файла
            const stats = fs.statSync(filePath);

            // Загружаем файл
            await this.client.fPutObject(bucketName, objectName, filePath, metaData);

            logger.info(`[MinIO] ✅ Файл загружен:`, {
                bucket: bucketName,
                object: objectName,
                size: `${(stats.size / 1024).toFixed(2)}KB`,
                contentType,
            });

            // Возвращаем публичный URL
            return this.getPublicUrl(bucketName, objectName);
        } catch (error: any) {
            logger.error(`[MinIO] ❌ Ошибка загрузки файла:`, {
                bucket: bucketName,
                object: objectName,
                error: error.message,
            });
            throw error;
        }
    }

    /**
     * Загрузить файл из Buffer
     */
    async uploadBuffer(
        bucketName: BucketName,
        objectName: string,
        buffer: Buffer,
        contentType?: string
    ): Promise<string> {
        try {
            const metaData = contentType ? { 'Content-Type': contentType } : {};

            await this.client.putObject(bucketName, objectName, buffer, buffer.length, metaData);

            logger.info(`[MinIO] ✅ Buffer загружен:`, {
                bucket: bucketName,
                object: objectName,
                size: `${(buffer.length / 1024).toFixed(2)}KB`,
                contentType,
            });

            return this.getPublicUrl(bucketName, objectName);
        } catch (error: any) {
            logger.error(`[MinIO] ❌ Ошибка загрузки buffer:`, {
                bucket: bucketName,
                object: objectName,
                error: error.message,
            });
            throw error;
        }
    }

    /**
     * Удалить файл из MinIO
     */
    async deleteFile(bucketName: BucketName, objectName: string): Promise<void> {
        try {
            await this.client.removeObject(bucketName, objectName);
            logger.info(`[MinIO] ✅ Файл удалён: ${bucketName}/${objectName}`);
        } catch (error: any) {
            logger.error(`[MinIO] ❌ Ошибка удаления файла:`, {
                bucket: bucketName,
                object: objectName,
                error: error.message,
            });
            throw error;
        }
    }

    /**
     * Получить публичный URL файла
     */
    getPublicUrl(bucketName: string, objectName: string): string {
        return `${MINIO_PUBLIC_URL}/${bucketName}/${objectName}`;
    }

    /**
     * Получить presigned URL для загрузки (если нужна прямая загрузка с клиента)
     */
    async getPresignedUploadUrl(
        bucketName: BucketName,
        objectName: string,
        expirySeconds: number = 3600
    ): Promise<string> {
        return await this.client.presignedPutObject(bucketName, objectName, expirySeconds);
    }

    /**
     * Проверить существование файла
     */
    async fileExists(bucketName: BucketName, objectName: string): Promise<boolean> {
        try {
            await this.client.statObject(bucketName, objectName);
            return true;
        } catch {
            return false;
        }
    }

    /**
     * Получить список файлов в папке
     */
    async listFiles(bucketName: BucketName, prefix?: string): Promise<Minio.BucketItem[]> {
        return new Promise((resolve, reject) => {
            const files: Minio.BucketItem[] = [];
            const stream = this.client.listObjects(bucketName, prefix, true);

            stream.on('data', (obj) => files.push(obj));
            stream.on('error', reject);
            stream.on('end', () => resolve(files));
        });
    }

    /**
     * Получить информацию о файле
     */
    async getFileInfo(bucketName: BucketName, objectName: string): Promise<Minio.BucketItemStat | null> {
        try {
            return await this.client.statObject(bucketName, objectName);
        } catch {
            return null;
        }
    }

    /**
     * Копировать файл внутри MinIO
     */
    async copyFile(
        sourceBucket: BucketName,
        sourceObject: string,
        destBucket: BucketName,
        destObject: string
    ): Promise<string> {
        try {
            const conds = new Minio.CopyConditions();
            await this.client.copyObject(destBucket, destObject, `/${sourceBucket}/${sourceObject}`, conds);
            logger.info(`[MinIO] ✅ Файл скопирован: ${sourceBucket}/${sourceObject} -> ${destBucket}/${destObject}`);
            return this.getPublicUrl(destBucket, destObject);
        } catch (error: any) {
            logger.error(`[MinIO] ❌ Ошибка копирования файла:`, { error: error.message });
            throw error;
        }
    }

    /**
     * Получить MinIO клиент для расширенных операций
     */
    getClient(): Minio.Client {
        return this.client;
    }

    /**
     * Проверить состояние подключения
     */
    async healthCheck(): Promise<{ status: 'ok' | 'error'; message: string }> {
        try {
            await this.client.listBuckets();
            return { status: 'ok', message: 'MinIO connection healthy' };
        } catch (error: any) {
            return { status: 'error', message: error.message };
        }
    }
}

// Экспортируем singleton
export const minioService = new MinioService();
export default minioService;
