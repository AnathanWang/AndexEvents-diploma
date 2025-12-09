import type { Response } from 'express';
import type { AuthRequest } from '../middleware/auth.middleware.js';

class UploadController {
    async uploadFile(req: AuthRequest, res: Response) {
        console.log('Upload request received (Local Storage)');
        try {
            const file = (req as any).file;
            if (!file) {
                return res.status(400).json({
                    success: false,
                    message: 'No file uploaded',
                });
            }

            // File is already saved to disk by multer
            const fileName = file.filename;
            
            // Construct public URL
            // Assuming the server is accessible via the same host as the request
            const protocol = req.protocol;
            const host = req.get('host');
            const publicUrl = `${protocol}://${host}/uploads/${fileName}`;

            console.log(`File saved locally: ${fileName}`);
            console.log(`Public URL: ${publicUrl}`);

            return res.json({
                success: true,
                url: publicUrl,
            });

        } catch (error: any) {
            console.error('Upload error:', error.message);
            return res.status(500).json({
                success: false,
                message: 'Upload failed',
                error: error.message
            });
        }
    }
}

export default new UploadController();
