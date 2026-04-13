from __future__ import annotations

from fastmcp import FastMCP


def create_mcp_server() -> FastMCP:
    """Create the demo MCP server exposed by ECS."""

    server = FastMCP(
        "Arithmetic Demo 🚀",
        instructions=(
            "A tiny example MCP server used to verify Keycloak-protected "
            "Streamable HTTP deployments on ECS Fargate."
        ),
    )

    @server.tool
    def add(a: int, b: int) -> int:
        """Add two integers and return the result."""

        return a + b

    return server


mcp = create_mcp_server()


if __name__ == "__main__":
    mcp.run()