import Foundation

enum OpenAPISpec {
    static let yaml = """
    openapi: 3.1.0
    info:
      title: agent-watch API
      version: 0.1.0
      description: Local screen-text memory API.
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
