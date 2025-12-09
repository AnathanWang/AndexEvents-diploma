import { createClient } from '@supabase/supabase-js';
import type { Request, Response } from 'express';
import type { AuthRequest } from '../middleware/auth.middleware.js';
import fetch from 'node-fetch';

// Initialize Supabase client lazily
let supabaseInstance: ReturnType<typeof createClient> | null = null;

function getSupabase() {
    if (supabaseInstance) return supabaseInstance;

    const supabaseUrl = process.env.SUPABASE_URL || 'https://rykbewslbfxltmipyseg.supabase.co';
    const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

    console.log('Initializing Supabase Client...');
    console.log('Supabase URL:', supabaseUrl);
    console.log('Supabase Key present:', !!supabaseKey);

    if (!supabaseKey) {
        console.warn('WARNING: SUPABASE_SERVICE_ROLE_KEY is not set. Uploads will fail.');
    }

    supabaseInstance = createClient(supabaseUrl, supabaseKey || 'placeholder', {
        global: {
            fetch: fetch as any,
        },
        auth: {
            persistSession: false,
        },
    });
    return supabaseInstance;
}

class UploadController {
    async uploadFile(req: AuthRequest, res: Response) {
        console.log('Upload request received');
        try {
            const supabase = getSupabase();
            const file = (req as any).file;
            if (!file) {
                return res.status(400).json({
                    success: false,
                    message: 'No file uploaded',
                });
            }

            const userId = req.user?.userId;
            if (!userId) {
                return res.status(401).json({
                    success: false,
                    message: 'Unauthorized',
                });
            }

            const fileExt = file.originalname.split('.').pop();
            const fileName = `${userId}_event_${Date.now()}.${fileExt}`;

            console.log(`Starting upload to Supabase: ${fileName}`);
            console.log(`File details: size=${file.size}, mimetype=${file.mimetype}`);
            
            // Upload to Supabase Storage with timeout configuration
            const uploadPromise = supabase.storage
                .from('events')
                .upload(fileName, file.buffer, {
                    contentType: file.mimetype,
                    upsert: false,
                });
            
            // Add timeout wrapper (60 seconds)
            const timeoutPromise = new Promise((_, reject) => {
                setTimeout(() => reject(new Error('Upload timeout after 60 seconds')), 60000);
            });
            
            const { error } = await Promise.race([uploadPromise, timeoutPromise]) as any;
            
            console.log('Supabase upload completed. Error:', error);

            if (error) {
                console.error('Supabase upload error:', error);
                return res.status(500).json({
                    success: false,
                    message: 'Failed to upload file to storage',
                    error: error.message,
                });
            }

            // Get public URL
            const { data: publicUrlData } = supabase.storage
                .from('events')
                .getPublicUrl(fileName);

            res.status(200).json({
                success: true,
                data: {
                    url: publicUrlData.publicUrl,
                },
            });

        } catch (error) {
            console.error('Upload controller error:', error);
            res.status(500).json({
                success: false,
                message: 'Internal server error during upload',
            });
        }
    }
}

export default new UploadController();
