extends RefCounted

const MAGIC := 0x31584452 # RDX1, little endian
const LITERAL := 0xffffffff
const BUFFER_SIZE := 65536

static func reconstruct(recipe_path: String, source_path: String, target_path: String, target_size: int) -> bool:
	var recipe := FileAccess.open(recipe_path,FileAccess.READ)
	var source := FileAccess.open(source_path,FileAccess.READ)
	if recipe == null or source == null or recipe.get_length()<12 or recipe.get_32()!=MAGIC: return false
	var target := FileAccess.open(target_path,FileAccess.WRITE)
	if target == null: return false
	var written := 0
	while recipe.get_position() < recipe.get_length():
		if recipe.get_length()-recipe.get_position()<8: return false
		var offset := recipe.get_32()
		var count := recipe.get_32()
		if count==0 or count>target_size-written: return false
		var input := recipe if offset==LITERAL else source
		if offset!=LITERAL:
			if offset>source.get_length(): return false
			source.seek(offset)
		if count>input.get_length()-input.get_position(): return false
		written += count
		while count>0:
			var length := mini(count,BUFFER_SIZE)
			var bytes := input.get_buffer(length)
			if bytes.size()!=length: return false
			target.store_buffer(bytes)
			if target.get_error()!=OK: return false
			count -= length
	target.flush()
	return target.get_error()==OK and written==target_size
