import Hummingbird

protocol HBMiddleware {
    func apply<Context: RequestContext>(
        to request: Request,
        context: Context,
        next: (Request, Context) async throws -> Response
    ) async throws -> Response
}
