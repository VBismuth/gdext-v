module gdext

// Prevents TLS destructors from being registered on Linux to support hot reloading.
//
// Adapted from godot-rust workaround:
// https://fasterthanli.me/articles/so-you-want-to-live-reload-rust#what-can-prevent-dlclose-from-unloading-a-library
import dl

type ThreadAtexitFn = fn (voidptr, voidptr, voidptr)

struct Reload {
mut:
	enabled bool
	handle  voidptr
}

pub fn (mut g GDExt) enable_hot_reload() {
	g.reload.enabled = true

	// open the handle
	g.reload.handle = dl.open(get_library_path(), dl.rtld_lazy | dl.rtld_nodelete)
}

pub fn (mut g GDExt) disable_hot_reload() {
	g.reload.enabled = false

	// close the handle
	if g.reload.handle != unsafe { nil } {
		dl.close(g.reload.handle)
		g.reload.handle = unsafe { nil }
	}
}

fn get_library_path() string {
	return './lib/libvlang.so'
}

@[export: '__cxa_thread_atexit_impl']
pub fn (mut g GDExt) cxa_thread_atexit(func voidptr, obj voidptr, dso voidptr) {
	if g.reload.enabled {
		return
	}

	// lazy init
	sym := dl.sym(dl.rtld_next, '__cxa_thread_atexit_impl')
	if sym == unsafe { nil } {
		return
	}

	// call real implementation
	atexit_fn := unsafe { *(&ThreadAtexitFn(sym)) }
	atexit_fn(func, obj, dso)
}
