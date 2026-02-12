import admin from 'firebase-admin';
export const authMiddleware = async (req, res, next) => {
    try {
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            res.status(401).json({
                success: false,
                message: 'Unauthorized: No token provided',
            });
            return;
        }
        const token = authHeader.split('Bearer ')[1];
        if (!token) {
            res.status(401).json({
                success: false,
                message: 'Unauthorized: Invalid token format',
            });
            return;
        }
        try {
            const decodedToken = await admin.auth().verifyIdToken(token);
            req.user = {
                uid: decodedToken.uid,
                email: decodedToken.email ?? undefined,
            };
            next();
        }
        catch (error) {
            res.status(401).json({
                success: false,
                message: 'Unauthorized: Invalid token',
            });
        }
    }
    catch (error) {
        res.status(500).json({
            success: false,
            message: 'Internal server error',
        });
    }
};
//# sourceMappingURL=auth.middleware.js.map