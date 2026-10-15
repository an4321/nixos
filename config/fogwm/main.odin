package main

import "core:c"
import "core:fmt"
import "core:os"
import "core:sys/posix"
import x "vendor:x11/xlib"

BAR_HEIGHT :: 24
NUM_TAGS   :: 5
TAG_WIDTH  :: 50

Client :: struct {
	win: x.Window,
	tag: int,
}

WM :: struct {
	dpy:      ^x.Display,
	root:     x.Window,
	screen:   c.int,
	sw, sh:   c.int,
	bar_win:  x.Window,
	bar_gc:   x.GC,
	cur_tag:  int,
	clients:  [dynamic]Client,
	focused:  x.Window,

	bg_norm:  c.ulong,
	fg_norm:  c.ulong,
	bg_sel:   c.ulong,
	fg_sel:   c.ulong,
}

wm: WM

// Ignore X11 non-fatal errors (e.g., bad window access when closing)
wm_error_handler :: proc "c" (dpy: ^x.Display, err: ^x.XErrorEvent) -> c.int {
	return 0
}

spawn :: proc(cmd: cstring) {
	pid := posix.fork()
	if pid == 0 {
		if wm.dpy != nil {
			x.XCloseDisplay(wm.dpy)
		}
		args := [?]cstring{cmd, nil}
		posix.execvp(cmd, &args[0])
		posix.exit(1)
	}
}

draw_bar :: proc() {
	x.XClearWindow(wm.dpy, wm.bar_win)

	for i in 0 ..< NUM_TAGS {
		x_pos := i32(i * TAG_WIDTH)

		if i == wm.cur_tag {
			x.XSetForeground(wm.dpy, wm.bar_gc, wm.bg_sel)
			x.XFillRectangle(wm.dpy, wm.bar_win, wm.bar_gc, x_pos, 0, TAG_WIDTH, BAR_HEIGHT)
			x.XSetForeground(wm.dpy, wm.bar_gc, wm.fg_sel)
		} else {
			x.XSetForeground(wm.dpy, wm.bar_gc, wm.fg_norm)
		}

		label := fmt.ctprintf("[%d]", i + 1)
		x.XDrawString(wm.dpy, wm.bar_win, wm.bar_gc, x_pos + 14, 16, label, c.int(len(label)))
	}

	// Draw top border for the bar
	x.XSetForeground(wm.dpy, wm.bar_gc, wm.bg_sel)
	x.XDrawLine(wm.dpy, wm.bar_win, wm.bar_gc, 0, 0, wm.sw, 0)
}

arrange :: proc() {
	for c in wm.clients {
		if c.tag == wm.cur_tag {
			x.XMapWindow(wm.dpy, c.win)
			// Fullscreen minus bottom bar
			x.XMoveResizeWindow(
				wm.dpy,
				c.win,
				0,
				0,
				u32(wm.sw),
				u32(wm.sh - BAR_HEIGHT),
			)
			x.XRaiseWindow(wm.dpy, c.win)
			x.XSetInputFocus(wm.dpy, c.win, x.RevertToPointerRoot, x.CurrentTime)
			wm.focused = c.win
		} else {
			x.XUnmapWindow(wm.dpy, c.win)
		}
	}
	draw_bar()
}

grab_keys :: proc() {
	x.XUngrabKey(wm.dpy, x.AnyKey, x.AnyModifier, wm.root)

	mod := u32(x.Mod4Mask) // Super Key

	// Super + Return -> Terminal
	kc_return := x.XKeysymToKeycode(wm.dpy, x.XStringToKeysym("Return"))
	x.XGrabKey(wm.dpy, c.int(kc_return), mod, wm.root, true, x.GrabModeAsync, x.GrabModeAsync)

	// Super + Shift + C -> Close Window
	kc_c := x.XKeysymToKeycode(wm.dpy, x.XStringToKeysym("c"))
	x.XGrabKey(wm.dpy, c.int(kc_c), mod | x.ShiftMask, wm.root, true, x.GrabModeAsync, x.GrabModeAsync)

	// Super + 1..5 & Super + Shift + 1..5
	for i in 1 ..= NUM_TAGS {
		tag_str := fmt.ctprintf("%d", i)
		kc := x.XKeysymToKeycode(wm.dpy, x.XStringToKeysym(tag_str))

		x.XGrabKey(wm.dpy, c.int(kc), mod, wm.root, true, x.GrabModeAsync, x.GrabModeAsync)
		x.XGrabKey(wm.dpy, c.int(kc), mod | x.ShiftMask, wm.root, true, x.GrabModeAsync, x.GrabModeAsync)
	}
}

init_wm :: proc() {
	wm.dpy = x.XOpenDisplay(nil)
	if wm.dpy == nil {
		fmt.println("Error: Cannot open X display")
		os.exit(1)
	}

	x.XSetErrorHandler(wm_error_handler)

	wm.screen = x.XDefaultScreen(wm.dpy)
	wm.root   = x.XRootWindow(wm.dpy, wm.screen)
	wm.sw     = x.XDisplayWidth(wm.dpy, wm.screen)
	wm.sh     = x.XDisplayHeight(wm.dpy, wm.screen)
	wm.cur_tag = 0
	wm.clients = make([dynamic]Client)

	// Allocate Colors (dwm theme palette)
	cmap := x.XDefaultColormap(wm.dpy, wm.screen)
	cn_bg, cn_fg, cs_bg, cs_fg: x.XColor

	x.XAllocNamedColor(wm.dpy, cmap, "#222222", &cn_bg, &cn_bg)
	x.XAllocNamedColor(wm.dpy, cmap, "#bbbbbb", &cn_fg, &cn_fg)
	x.XAllocNamedColor(wm.dpy, cmap, "#005577", &cs_bg, &cs_bg)
	x.XAllocNamedColor(wm.dpy, cmap, "#ffffff", &cs_fg, &cs_fg)

	wm.bg_norm = cn_bg.pixel
	wm.fg_norm = cn_fg.pixel
	wm.bg_sel  = cs_bg.pixel
	wm.fg_sel  = cs_fg.pixel

	// Register Substructure Redirection on Root Window
	x.XSelectInput(wm.dpy, wm.root, x.SubstructureRedirectMask | x.SubstructureNotifyMask)

	// Create Bottom Bar Window
	wm.bar_win = x.XCreateSimpleWindow(
		wm.dpy,
		wm.root,
		0,
		wm.sh - BAR_HEIGHT,
		u32(wm.sw),
		u32(BAR_HEIGHT),
		0,
		wm.fg_sel,
		wm.bg_norm,
	)

	x.XSelectInput(wm.dpy, wm.bar_win, x.ExposureMask | x.ButtonPressMask)
	x.XMapWindow(wm.dpy, wm.bar_win)

	wm.bar_gc = x.XCreateGC(wm.dpy, wm.bar_win, 0, nil)

	grab_keys()
	draw_bar()
}

run :: proc() {
	ev: x.XEvent

	for {
		x.XNextEvent(wm.dpy, &ev)

		#partial switch ev.type {
		case x.MapRequest:
			mre := ev.xmaprequest
			managed := false
			for c in wm.clients {
				if c.win == mre.window {
					managed = true; break
				}
			}
			if !managed && mre.window != wm.bar_win {
				append(&wm.clients, Client{win = mre.window, tag = wm.cur_tag})
				x.XSelectInput(wm.dpy, mre.window, x.PropertyChangeMask)
				arrange()
			}

		case x.DestroyNotify:
			dne := ev.xdestroywindow
			for i := 0; i < len(wm.clients); i += 1 {
				if wm.clients[i].win == dne.window {
					unordered_remove(&wm.clients, i)
					break
				}
			}
			arrange()

		case x.UnmapNotify:
			unm := ev.xunmap
			if unm.send_event {
				for i := 0; i < len(wm.clients); i += 1 {
					if wm.clients[i].win == unm.window {
						unordered_remove(&wm.clients, i)
						break
					}
				}
				arrange()
			}

		case x.KeyPress:
			kpe := ev.xkey
			sym := x.XKeycodeToKeysym(wm.dpy, x.KeyCode(kpe.keycode), 0)

			// Terminal Launcher
			if sym == x.XStringToKeysym("Return") && (kpe.state & x.Mod4Mask) != 0 {
				spawn("xterm")
			}

			// Close Window
			if sym == x.XStringToKeysym("c") && (kpe.state & x.Mod4Mask) != 0 && (kpe.state & x.ShiftMask) != 0 {
				if wm.focused != 0 && wm.focused != wm.bar_win {
					x.XKillClient(wm.dpy, wm.focused)
				}
			}

			// Workspace Switching & Moving
			for i in 1 ..= NUM_TAGS {
				tag_str := fmt.ctprintf("%d", i)
				if sym == x.XStringToKeysym(tag_str) {
					target_tag := i - 1
					if (kpe.state & x.ShiftMask) != 0 {
						for &c in wm.clients {
							if c.win == wm.focused {
								c.tag = target_tag
								break
							}
						}
					} else {
						wm.cur_tag = target_tag
					}
					arrange()
					break
				}
			}

		case x.ButtonPress:
			bpe := ev.xbutton
			if bpe.window == wm.bar_win && bpe.button == 1 {
				clicked_tag := int(bpe.x) / TAG_WIDTH
				if clicked_tag >= 0 && clicked_tag < NUM_TAGS {
					wm.cur_tag = clicked_tag
					arrange()
				}
			}

		case x.Expose:
			exp := ev.xexpose
			if exp.window == wm.bar_win {
				draw_bar()
			}
		}
	}
}

main :: proc() {
	init_wm()
	run()
}
