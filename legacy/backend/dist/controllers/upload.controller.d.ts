import type { Response } from 'express';
import type { AuthRequest } from '../middleware/auth.middleware.js';
declare class UploadController {
    uploadFile(req: AuthRequest, res: Response): Promise<Response<any, Record<string, any>>>;
}
declare const _default: UploadController;
export default _default;
//# sourceMappingURL=upload.controller.d.ts.map