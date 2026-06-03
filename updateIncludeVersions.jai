main :: () {
	content, success := read_entire_file("D:/cygwin64/Cygwin.bat");
	assert(success);
	lines := split(content, "\r\n");
	for lines {
		changed := false;
		if starts_with(it, "set ") && contains(it, #char ";") {
			found, prefix, value := split_from_left(it, #char "=");
			print("~~~ \e[1m%\e[0m ~~~\n", prefix);
			assert(found);
			paths := split(value, ";");
			for * paths {
				if it.* == "%PATH%"  continue;

				pathStr := copy_string(it.*,, temp);
				path_overwrite_separators(pathStr, #char "/");
				path := parse_path(pathStr,, temp);
				all, index := how_much_of_path_exists_on_the_local_filesystem(path);
				if !all {
					print("   Path does not fully exist: %\n", it.*);
					print("      Existing part: %\n", path_to_string(path, index));
					print("      Missing part: %\n", path.words[index]);
				}

				found=, new := verifyPath(path);
				if found {
					changed = true;
					path_overwrite_separators(new);
					print("! ! ! Path updated\nfrom: %\n  to: %\n", it.*, new);
					it.* = new;
					break;
				}
			}
		}

		if changed {
			print("\e[1m%s\e[0m\n", it);
		}
	}
}

isVersion :: (part: string) -> bool {
	ver := true;
	for part {
		ver &&= it >= #char "0" && it <= #char "9" || it == #char "." || it == #char "_";
		if !ver  return false;
	}


	return true;
}

gt :: (a: string, b: string) -> bool {
	for a {
		if it_index >= b.count  return true;
		if it < b[it_index]  return false;
	}

	return true;
}

UD :: struct {
	it: string;
	max: *string;
}

verifyPath :: (path: Path) -> (success: bool, alt: string = "") {
	//debug_break();
	for path.words {
		if isVersion(it) {
			//print("   Found version: %\n", it);
			ud := UD.{it, *it};
			visit_files(path_to_string(path, it_index), false, ud, (info/*: *File_Visit_Info*/, userData/*: T*/) => {
				if info.short_name == userData.it || !isVersion(info.short_name)  return;
				//print("      Found alt: %\n", info.short_name);
				if gt(info.short_name, userData.max.*) {
					//print("! ! ! Found newer version: %\n", info.short_name);
					userData.max.* = info.short_name;
				}
			}, visit_files = false, visit_directories = true,, temp);
			if ud.max.* != ud.it {
				prefix := path_to_string(path, it_index);
				return true, join(prefix, ud.max.*, advance(path_to_string(path), prefix.count + ud.max.count),, temp);
			}
		}
	}

	return false;
}

#import "Basic";
#import "File";
#import "File_Utilities";
#import "String";

//#run main();
