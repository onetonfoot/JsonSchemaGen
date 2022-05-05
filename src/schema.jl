# object like json schema types
# https://json-schema.org/draft/2020-12/json-schema-core.html
# https://json-schema.org/understanding-json-schema/index.html
# https://opis.io/json-schema
using StructTypes
using StructTypes: OrderedStruct, UnorderedStruct, Mutable, DictType
using StructTypes:  ArrayType
using StructTypes: StringType, NumberType, BoolType, NullType
using Dates
using UUIDs
using Base.Docs
using URIs: URI
using AbstractTrees

const array_types = [ArrayType()]
const object_types = [OrderedStruct(), UnorderedStruct(), Mutable(), DictType()]
const primative_types = [StringType(), NumberType(), BoolType(), NullType()]

function union_types(t)
	l = []
	if t.a isa Union
		push!(l, union_types(t.a)...)
	else  
		push!(l, t.a)
	end

	if t.b isa Union
		push!(l, union_types(t.b)...)
	else  
		push!(l, t.b)
	end
	l
end

json_type(::Type{Bool}) = "boolean"
json_type(::Type{<:Integer}) =  "integer"
json_type(::Type{<:Real}) =  "number"
json_type(::Type{Nothing}) =  "null"
json_type(::Type{Missing}) =  "null"
json_type(::Type{String}) =  "string"
json_type(::Type{<:Enum}) =  "string"
array_type(::Type{<:Vector{T}}) where T = T
array_type(::Type{<:Array{T}}) where T = T

function doc_str(t::Type{T}) where T
	# Docs.getdocs could be usefull here
	md = Docs.doc(T)
	s = repr(md)
	if startswith(s, "No documentation found.")
		return nothing
	else
		return s
	end
end

function json_schema(::Type{T}, d = Dict{Symbol, Any}(); root = nothing , path = "/") where T

	@info "enter" type=T

	if isnothing(root)
		root = d
	end

	if path != "/"
		path = joinpath(path, T)
	end



	if T isa Union
		@info "union"

		return JSONSchema(
			oneOf = unique(json_schema.(union_types(T)))
		)
	end

	sT = StructTypes.StructType(T)

	# http://json-schema.org/understanding-json-schema/reference/object.html
	if sT in object_types
		d[:type] = "object"
		d[:description] = doc_str(T)
		required = []
		if !(sT == DictType())
			properties = Dict{String, Any}()
			StructTypes.foreachfield(T) do  i, field, field_type
				field_schema = json_schema(field_type; root = root, path = path)
				push!(properties, string(field) => field_schema)

				if T isa Union
					ts = union_types(T)
					if !(Missing in ts || Nothing in ts) 
						push!(required, string(field))
					end
				else 
					push!(required, string(field))
				end

			end
			d[:additionalProperties] = false
			d[:properties] = properties
			d[:required] = required
		end
	# http://json-schema.org/understanding-json-schema/reference/array.html
	elseif sT in array_types
		d[:type] = "array"
		if T <: Tuple
			d[:prefixItems] = map(x -> json_schema(x), T.types)
		end
		if T <: Array 
			aT = array_type(T)
			if aT isa Union
				error("union types in arrays are not supported")
			end
			d[:items] = json_schema(aT)
		end
	elseif sT in primative_types
		if T <: Enum
			d[:description] = doc_str(T)
			d[:enum] = Base.Enums.namemap(T) |> values |> collect .|> String
		else
			d[:type] = json_type(T)
		end
	else
		error("unable to determin json_schema for $T")
	end

	@info "result" res=d
	schema = JSONSchema{T}(;d...)

	if isnothing(schema.type) && 
	   isnothing(schema.anyOf) &&
	   isnothing(schema.enum) &&
	   isnothing(schema.oneOf) &&
	   isnothing(schema.not)
		@warn "No data type in schema"
	end

	return schema
end


# @enum JSONSchemaFormat 

# str enum regex object boolean null array integer number
JSONSchemaType = String


function json_schema_format(x::Type{T}) where T

	# renaming valid formats
	# "hostname"
	# "idn-hostname"
	# "ipv4"
	# "ipv6"
	# "uri-reference"
	# "iri"
	# "ir-reference"
	# "uri-template"
	# "json-pointer"

	return if x <: DateTime
		"date-time"
	elseif x <: Time
		"time"
	elseif x <: Date
		"date"
	elseif x <: TimePeriod
		"duration"
	elseif x <: AbstractString
		"email"
		"idn-email"
	elseif x <: UUID
		"uuid"
	elseif x <: Regex
		"regex"
	elseif x <: URI
		"uri"
	else 
		error("unsupported type $x")
	end
end



Base.@kwdef mutable struct JSONSchema{T}
	# can it really be and array of types?
	type::Union{Nothing, JSONSchemaType} = nothing

	enum::Union{Nothing, Vector{String}} = nothing

	# schema composition
	allOf::Union{Nothing, Vector{JSONSchema}} = nothing
	anyOf::Union{Vector{JSONSchema}, Nothing} = nothing
	oneOf::Union{Nothing, Vector{JSONSchema}} = nothing
	not::Union{Nothing, Vector{JSONSchema}} = nothing

	# string related fields #
	maxLength::Union{Int, Nothing} = nothing
	minLength::Union{Int, Nothing} = nothing
	pattern::Union{Regex, Nothing} = nothing
	format::Union{String, Nothing} = nothing

	# number releated fields #
	multipleOf::Union{Int, Nothing} = nothing
	minimum::Union{Int, Nothing} = nothing
	exclusiveMinimum::Union{Int, Nothing} = nothing
	maximum::Union{Int, Nothing} = nothing
	exclusiveMaximum::Union{Int, Nothing} = nothing

	# object related fields #
	properties::Union{Dict{String, Any}, Nothing} = nothing
	parternProperties::Union{Dict{Regex, Any}, Nothing} = nothing
	additionalProperties::Union{Union{Bool, Any}, Nothing} = nothing
	required::Union{Array{String}, Nothing} = nothing
	propertiesNames::Union{Pair{String, String}, Nothing} = nothing
	minProperties::Union{Int, Nothing} = nothing
	maxProperties::Union{Int, Nothing} = nothing
	const_::Union{Any, Nothing} = nothing

	# array releated fields #
	items::Union{JSONSchema, Nothing, Bool} = nothing
	prefixItems::Union{Vector{JSONSchema}, Nothing} = nothing
	additionalItem::Union{Bool, Nothing} = nothing
	contains::Union{Vector{JSONSchema}, Nothing} = nothing
	unqiueItems::Union{Bool, Nothing} = nothing
	minItems::Union{Int, Nothing} = nothing
	maxItems::Union{Int, Nothing} = nothing

	# generic fields #
	title::Union{String, Nothing} = nothing
	description::Union{String, Nothing} = nothing
	examples::Union{Array{Any}, Nothing} = nothing
	deprecated::Union{Bool, Nothing} = nothing
	readOnly::Union{Bool, Nothing} = nothing
	writeOnly::Union{Bool, Nothing} = nothing
	ref::Union{String, Nothing} = nothing
	defs::Union{Dict{String, JSONSchema}, Nothing} = nothing
end

StructTypes.StructType(::Type{<:JSONSchema}) where T = StructTypes.Struct()
StructTypes.omitempties(::Type{<:JSONSchema}) where T = true

function AbstractTrees.children(s::JSONSchema{T}) where T
	l = []
	if s.type == "object"
		push!(l, values(s.properties)...)
	end

	push!(l, s.oneOf)
	filter!(!isnothing, l)
	l
end

AbstractTrees.nodetype(::JSONSchema) = JSONSchema


# Base.show(io::IO, JSONSchema)


#TODO: handle arrays
isprimative(j::JSONSchema) = !(j.type in ["object"])

function clear_schema!(schema::JSONSchema) 
	for i in fieldnames(JSONSchema)
		setfield!(schema, i, nothing)
	end
end

function StructTypes.names(::Type{<:JSONSchema})
	l = []
	for i in fieldnames(JSONSchema)
		push!(l, (i, key_name(i)))
	end
	tuple(l...)
end


function key_name(s::Symbol)
	if s == :ref
		Symbol("\$ref")
	elseif s == :defs
		Symbol("\$defs")
	else
		s
	end
end

function create_refs!(outer_schema)
	for i in PostOrderDFS(outer_schema)

		if i === outer_schema
			continue
		end

		if !isprimative(i)
			println(typeof(i))
			if isnothing(outer_schema.defs)
				outer_schema.defs = Dict()
			end
			k = struct_name(i)
			outer_schema.defs[k] = deepcopy(i)
			clear_schema!(i)
			i.ref = "#/\$defs/" * k
		end
	end
	outer_schema
end

function struct_name(t::DataType)
	string(t)
end

struct_name(x) = struct_name(typeof(x))
