using Test, JsonSchemaGen
using StructTypes
using StructTypes: @Struct
using JSON3
using AbstractTrees
using AbstractTrees: children
using JsonSchemaGen: isprimative, create_refs!, quicktype, quicktype_args


@Struct struct A
	x::Int
	y::Float64
	z::UInt
end

a = A(1,2,3)

a_schema = json_schema(A)
JSON3.write("a.json", a_schema)


@Struct struct InnerA
	x::Int
	y::String
end

@Struct struct InnerB
	x::Int
	y::String
end

@Struct struct Outer 
	a::InnerA
	b::InnerB
	c::Int
end



outer = Outer(
	InnerA(
		1,
		"1"
	),
	InnerB(
		2,
		"2"
	),
	3
)

# outer_schema = json_schema(Outer)
# create_refs!(outer_schema)
# JSON3.write("o.json", outer_schema)
# StructTypes.names(JSONSchema)
# quicktype_args(outer_schema, Val(:typescript))
# quicktype(outer_schema, Val(:typescript))
# using JsonSchemaGen: npx
# read(Cmd(`$npx quicktype --help`), String)