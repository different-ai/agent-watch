import Foundation

enum OpenAPISpec {
    static let yaml = """
    openapi: 3.1.0
    info:
      title: agent-watch API
      version: 0.2.0
      description: Local screen-text memory API with optional live capture.
    servers:
      - url: http://127.0.0.1:41733
    paths:
      /:
        get:
          summary: Discovery document
      /health:
        get:
          summary: Liveness probe
      /status:
        get:
          summary: Status and storage counts
      /latest:
        get:
          summary: Most recent capture records
          parameters:
            - in: query
              name: limit
              required: false
              schema:
                type: integer
                minimum: 1
                maximum: 50
      /capture:
        post:
          summary: Trigger a live screen-text capture
          description: Requires starting the server with `agent-watch serve --capture`.
      /search:
        get:
          summary: Full-text search endpoint
          parameters:
            - in: query
              name: q
              required: true
              schema:
                type: string
            - in: query
              name: limit
              required: false
              schema:
                type: integer
                minimum: 1
                maximum: 200
            - in: query
              name: app
              required: false
              schema:
                type: string
      /screen-recording/probe:
        get:
          summary: Probe current screen-recording capture ability
      /openapi.yaml:
        get:
          summary: OpenAPI spec (YAML)
    """
}
