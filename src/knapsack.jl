### Knapsack Model

struct Instance
    values::Vector{Float64}
    weights::Vector{Int}
    capacity::Int

    function Instance(values, weights, capacity)
        @assert length(values) == length(weights)
        new(values, weights, capacity)
    end
end
Base.length(instance::Instance) = length(instance.values)

struct State
    capacity::Int
end

function initial_state(instance::Instance)
    return State(instance.capacity)
end

"Iterator over decision variables."
struct VarsInOrder
    n::Int
end
VarsInOrder(instance::Instance) = VarsInOrder(length(instance))

function Base.iterate(iter::VarsInOrder, state=1)
    if state > iter.n
        nothing
    else
        state, state + 1
    end
end
Base.eltype(::Type{VarsInOrder}) = Int
Base.length(iter::VarsInOrder) = iter.n

struct VarsByWeightDecr
    perm::Vector{Int}
end
function VarsByWeightDecr(instance::Instance)
    perm = sortperm(1:length(instance), by=i->instance.weights[i], rev=true)
    VarsByWeightDecr(perm)
end

function Base.iterate(iter::VarsByWeightDecr, state=1)
    if state > length(iter.perm)
        nothing
    else
        iter.perm[state], state + 1
    end
end
Base.eltype(::Type{VarsByWeightDecr}) = Int
Base.length(iter::VarsByWeightDecr) = length(iter.perm)

function transitions(instance::Instance, state::State, variable::Int)
    results = Dict{Arc, State}()

    # true
    slack = state.capacity - instance.weights[variable]
    if slack >= 0
        arc = Arc(state, true, instance.values[variable])
        results[arc] = State(slack)
    end

    # false
    results[Arc(state, false, 0.0)] = state # unchanged

    return results
end

### Decision Diagram Implementation

struct Arc
    tail::State
    decision::Bool
    value::Float64
end

struct Node
    inarc::Union{Arc, Nothing}
    dist::Float64
end
Node() = Node(nothing, 0.0)

const Layer = Dict{State,Node}

struct DecisionDiagram
    layers::Vector{Layer}
    variables::Vector{Int}
end
DecisionDiagram() = DecisionDiagram([], [])

function add_transition(layer::Layer, new_state::State, new_node::Node)
    if haskey(layer, new_state)
        if new_node.dist > layer[new_state].dist
            layer[new_state] = new_node
        end
    else
        layer[new_state] = new_node
    end
end

function top_down(instance, variter, dd=DecisionDiagram())
    root = Layer(initial_state(instance) => Node())
    push!(dd.layers, root)

    # Intermediate layers
    for (depth, variable) in enumerate(variter)
        layer = Layer()

        # Collect new states, keep only "best" arcs.
        for (state, node) in dd.layers[end]
            for (arc, new_state) in transitions(instance, state, variable)
                new_node = Node(arc, node.dist + arc.value)
                add_transition(layer, new_state, new_node)
            end
        end

        push!(dd.layers, layer)
        push!(dd.variables, variable)
    end

    # Terminal node (last layer reduced to best)
    maxstate, maxnode = nothing, Node(nothing, -Inf)
    for (state, node) in dd.layers[end]
        if node.dist > maxnode.dist
            maxstate = state
            maxnode = node
        end
    end
    dd.layers[end] = Dict(maxstate => maxnode)

    return dd
end

struct Solution
    decisions::Vector{Bool}
    objective::Float64
end

function longest_path(dd::DecisionDiagram)
    # Collect path in reverse, from terminal to root.
    terminal = only(values(dd.layers[end]))
    decisions = Vector{Bool}(undef, length(dd.variables))
    node, depth = terminal, length(dd.layers) - 1
    while depth != 0
        decisions[dd.variables[depth]] = node.inarc.decision
        state = node.inarc.tail
        node = dd.layers[depth][state]
        depth -= 1
    end

    return Solution(decisions, terminal.dist)
end
