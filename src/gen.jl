using NodeJS, JSON3

function quicktype_args(::JSONSchema{<:T}, ::Val{:typescript}) where T
	`--lang typescript --just-types --top-level $(struct_name(T))`
end

const npx = joinpath(NodeJS.nodejs_path, "bin/npx")

quicktype_cmd() = `npx $quicktype`

function quicktype(s::JSONSchema{<:T}, v::Val) where T
	s = deepcopy(s)
	create_refs!(s)
	dir = mktempdir()
	JSON3.write(joinpath(dir, "in.json"), s)
	args = quicktype_args(s, v)
	run(Cmd(`$npx quicktype -s schema in.json $args --out outfile`, dir=dir))
	Base.read(joinpath(dir, "outfile"), String)
end

quicktype(t, v::Val) = quicktype(JSONSchema(t), v)