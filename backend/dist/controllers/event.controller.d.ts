import type { Request, Response } from "express";
declare class EventController {
    createEvent(req: Request, res: Response): Promise<void>;
    getAllEvents(req: Request, res: Response): Promise<void>;
    getEventById(req: Request, res: Response): Promise<Response<any, Record<string, any>> | undefined>;
}
declare const _default: EventController;
export default _default;
//# sourceMappingURL=event.controller.d.ts.map