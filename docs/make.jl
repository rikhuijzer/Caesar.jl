using Documenter, Caesar

makedocs(
    modules = [Caesar, RoME, IncrementalInference],
    format = :html,
    sitename = "Caesar.jl",
    pages = Any[
        "Home" => "index.md",
        "Getting Started" => [
            "Installation" => "installation_environment.md"
        ],
        "Concepts" => [
            "Caesar Concepts" => "concepts/concepts.md",
            "Building Factor Graphs" => "concepts/building_graphs.md",
            "Arena Visualization" => "concepts/arena_visualizations.md",
            "Using Caesar's Multi-Language Support" => "concepts/multilang.md",
            "Adding New Variables and Factors" => "concepts/adding_variables_factors.md",
            "Using Caesar Database Operation" => "concepts/database_interactions.md"
        ],
        "Examples" => [
            "Caesar Examples" => "examples/examples.md",
            "ContinuousScalar" => "examples/basic_continuousscalar.md",
            "Singular Ranges-only SLAM (Underdetermined System)" => "examples/basic_slamedonut.md",
            "Hexagonal 2D SLAM" => "examples/basic_hexagonal2d.md",
            "Fixed-Lag Solving" => "examples/interm_fixedlag_hexagonal.md",
            "Creating Custom Variables and Factors" => "examples/basic_definingfactors.md",
            "Creating DynPose Factor" => "examples/interm_dynpose.md"
        ],
        "Function Reference" => [
            "Function Reference" => "func_ref.md",
        ]
    ]
    # html_prettyurls = !("local" in ARGS),
    )


deploydocs(
    repo   = "github.com/JuliaRobotics/Caesar.jl.git",
    target = "build"
)