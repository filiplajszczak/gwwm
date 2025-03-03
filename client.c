#include "libguile/boolean.h"
#include "libguile/eval.h"
#include "libguile/goops.h"
#include "libguile/gsubr.h"
#include "libguile/list.h"
#include "libguile/numbers.h"
#include "libguile/scm.h"
#include "string.h"
#include <stdbool.h>
#include <stdint.h>
#include <wlr/types/wlr_scene.h>
#include "util.h"
#include "client.h"
#include "gwwm.h"
#include "listener.h"
#include "wayland-util.h"
#include <wlr/types/wlr_layer_shell_v1.h>
SCM find_client(Client *c) {
  return (c) ? c->scm : SCM_BOOL_F;
}

Client*
unwrap_client_1(SCM o)
{
  if (scm_is_false(o)) {
    return NULL;
  }
  SCM a=scm_call_1(REFP("gwwm client",".data"),o);
  if (scm_to_bool(scm_zero_p(a))) {
    scm_error(scm_misc_error_key,"unwrap-client","client is delated" ,SCM_EOL,SCM_EOL);
    return NULL;
  }
  return (TO_P(MAKE_P(a)));
}

void client_add_listen(void *c, struct wl_signal *signal,
                       wl_notify_func_t func) {
  struct wl_listener *listener =
      UNWRAP_WL_LISTENER((scm_register_gwwm_listener(WRAP_CLIENT(c))));
  listener->notify = func;
  wl_signal_add(signal, listener);
}

void register_client(Client *c, enum gwwm_client_type type) {
  PRINT_FUNCTION;
  char *tp = "<gwwm-xdg-client>";
  switch (type) {
  case GWWM_LAYER_CLIENT_TYPE:
    tp = "<gwwm-layer-client>";
    break;
  case GWWM_XDG_CLIENT_TYPE:
    tp = "<gwwm-xdg-client>";
    break;
  case GWWM_X_CLIENT_TYPE:
    tp = "<gwwm-x-client>";
    break;
  }
  SCM sc=(scm_call_3(REF("oop goops", "make"), REF("gwwm client", tp),
                              scm_from_utf8_keyword("data"),
                     scm_pointer_address(FROM_P(c))));
  c->scm=sc;
}

void *client_from_listener(struct wl_listener *listener) {
  /* PRINT_FUNCTION; */
  SCM scm = scm_from_listener(WRAP_WL_LISTENER(listener));
  return scm_is_false(scm) ? NULL : UNWRAP_CLIENT(scm);
}

void
logout_client(Client *c){
  PRINT_FUNCTION;
  SCM sc=WRAP_CLIENT(c);
  scm_call_1(REFP("gwwm client","logout-client") ,sc);
  c->scm=NULL;
  /* free(c); */
}

bool
client_is_x11(Client *c)
{
  return (scm_to_bool(REF_CALL_1("gwwm client","client-is-x11?", WRAP_CLIENT(c))));
}

Client *
client_from_wlr_surface(struct wlr_surface *s)
{
	struct wlr_xdg_surface *surface;

#ifdef XWAYLAND
	struct wlr_xwayland_surface *xsurface;
	if (s && wlr_surface_is_xwayland_surface(s)
			&& (xsurface = wlr_xwayland_surface_from_wlr_surface(s)))
		return UNWRAP_CLIENT(xsurface->data);
#endif
	if (s && wlr_surface_is_xdg_surface(s)
			&& (surface = wlr_xdg_surface_from_wlr_surface(s))
			&& surface->role == WLR_XDG_SURFACE_ROLE_TOPLEVEL)
		return UNWRAP_CLIENT(surface->data);

	if (s && wlr_surface_is_subsurface(s))
		return client_from_wlr_surface(wlr_surface_get_root_surface(s));
	return NULL;
}

/* The others */
void
client_activate_surface(struct wlr_surface *s, int activated)
{
	struct wlr_xdg_surface *surface;
#ifdef XWAYLAND
	struct wlr_xwayland_surface *xsurface;
	if (wlr_surface_is_xwayland_surface(s)
			&& (xsurface = wlr_xwayland_surface_from_wlr_surface(s))) {
		wlr_xwayland_surface_activate(xsurface, activated);
		return;
	}
#endif
	if (wlr_surface_is_xdg_surface(s)
			&& (surface = wlr_xdg_surface_from_wlr_surface(s))
			&& surface->role == WLR_XDG_SURFACE_ROLE_TOPLEVEL)
		wlr_xdg_toplevel_set_activated(surface, activated);
}

void client_for_each_alives(client_iterator_func_t fn){
  SCM l=REF_CALL_0("gwwm client", "client-list");
  int n=scm_to_int(scm_length(l));
  for (int i=0;i < n; i++){
    fn(UNWRAP_CLIENT(scm_list_ref(l, scm_from_int(i))));
  }
;
}

void
client_for_each_surface(Client *c, wlr_surface_iterator_func_t fn, void *data)
{
	wlr_surface_for_each_surface(CLIENT_SURFACE(c), fn, data);
#ifdef XWAYLAND
	if (client_is_x11(c))
		return;
#endif
	wlr_xdg_surface_for_each_popup_surface(wlr_xdg_surface_from_wlr_surface(CLIENT_SURFACE(c)), fn, data);
}

const char *
client_get_appid(Client *c)
{
  return scm_to_utf8_string(REF_CALL_1("gwwm client", "client-get-appid",(WRAP_CLIENT(c))));
}

struct wlr_scene_node *
client_scene_surface(Client *c, struct wlr_scene_node *surface) {
  SCM s;
  SCM scm_c= WRAP_CLIENT(c);
  if (surface) {
    s=WRAP_WLR_SCENE_NODE(surface);
    scm_slot_set_x(scm_c,scm_from_utf8_symbol("scene-surface"),s);
    return surface;
  } else {
    s=scm_slot_ref(scm_c,scm_from_utf8_symbol("scene-surface"));
    return scm_is_false(s) ? NULL : UNWRAP_WLR_SCENE_NODE(s);
}
}
int
client_tags(Client *c) {
  return exp2(scm_to_int(scm_slot_ref(WRAP_CLIENT(c),scm_from_utf8_symbol("tags"))));
}
void set_client_tags(Client *c,int tags) {
  scm_slot_set_x(WRAP_CLIENT(c), scm_from_utf8_symbol("tags"), scm_from_int(log2(tags)));
  /* c->tags=tags; */
}

struct wlr_box*
client_get_geometry(Client *c)
{
  return UNWRAP_WLR_BOX (REF_CALL_1("gwwm client", "client-get-geometry", WRAP_CLIENT(c)));
}

struct wlr_box* client_geom(void *c)
{
  /* PRINT_FUNCTION; */
  SCM sc=WRAP_CLIENT(c);
  SCM sbox=scm_slot_ref(sc,scm_from_utf8_symbol("geom"));
  return scm_is_false(sbox) ? NULL : UNWRAP_WLR_BOX(sbox);
}

void set_client_geom(Client *c , struct wlr_box* box)
{
  PRINT_FUNCTION;
  SCM sc=WRAP_CLIENT(c);
  scm_slot_set_x(sc,scm_from_utf8_symbol("geom"),
                          (box) ? SHALLOW_CLONE(WRAP_WLR_BOX(box)) : SCM_BOOL_F);
}


uint32_t client_resize_configure_serial(Client *c)
{
  return scm_to_uint32(scm_slot_ref(WRAP_CLIENT(c),scm_from_utf8_symbol("resize-configure-serial")));
}

void client_set_resize_configure_serial(Client *c, uint32_t i)
{
  scm_slot_set_x(WRAP_CLIENT(c),
                          scm_from_utf8_symbol("resize-configure-serial"),scm_from_uint32(i));
}


void
client_get_size_hints(Client *c, struct wlr_box *max, struct wlr_box *min)
{
	struct wlr_xdg_toplevel *toplevel;
	struct wlr_xdg_toplevel_state *state;
#ifdef XWAYLAND
	if (client_is_x11(c)) {
		struct wlr_xwayland_surface_size_hints *size_hints;
		size_hints = wlr_xwayland_surface_from_wlr_surface(CLIENT_SURFACE(c))->size_hints;
		if (size_hints) {
			max->width = size_hints->max_width;
			max->height = size_hints->max_height;
			min->width = size_hints->min_width;
			min->height = size_hints->min_height;
		}
		return;
	}
#endif
	toplevel = wlr_xdg_surface_from_wlr_surface(CLIENT_SURFACE(c))->toplevel;
	state = &toplevel->current;
	max->width = state->max_width;
	max->height = state->max_height;
	min->width = state->min_width;
	min->height = state->min_height;
}

SCM_DEFINE (gwwm_client_get_size_hints,"client-get-size-hints",1,0,0,
            (SCM c),"")
#define FUNC_NAME s_gwwm_client_get_size_hints
{
  GWWM_ASSERT_CLIENT_OR_FALSE(c ,1);
  struct wlr_box *min = ecalloc(sizeof(struct wlr_box *));
  struct wlr_box *max = ecalloc(sizeof(struct wlr_box *));
  Client *cl =UNWRAP_CLIENT(c);
  client_get_size_hints(cl, max, min);
  return scm_values_2(WRAP_WLR_BOX(max),WRAP_WLR_BOX(min));
}
#undef FUNC_NAME

const char *
client_get_title(Client *c)
{
  return (scm_to_utf8_string(REF_CALL_1("gwwm client","client-get-title", WRAP_CLIENT(c))));
}

Client *
client_get_parent(Client *c)
{
  PRINT_FUNCTION;
#ifdef XWAYLAND
	if (client_is_x11(c) && wlr_xwayland_surface_from_wlr_surface(CLIENT_SURFACE(c))->parent){
      return client_from_wlr_surface(wlr_xwayland_surface_from_wlr_surface(CLIENT_SURFACE(c))->parent->surface);
    }
#endif
    PRINT_FUNCTION;
	if (wlr_surface_is_xdg_surface(CLIENT_SURFACE(c)) && wlr_xdg_surface_from_wlr_surface(CLIENT_SURFACE(c))->toplevel->parent){
      PRINT_FUNCTION;
      return client_from_wlr_surface(wlr_xdg_surface_from_wlr_surface(CLIENT_SURFACE(c))->toplevel->parent->surface);
    }

	return NULL;
}

bool
client_is_float_type(Client *c)
{
	struct wlr_box min = {0}, max = {0};
	client_get_size_hints(c, &max, &min);

#ifdef XWAYLAND
	if (client_is_x11(c)) {
		struct wlr_xwayland_surface *surface = wlr_xwayland_surface_from_wlr_surface(CLIENT_SURFACE(c));
		if (surface->modal)
			return 1;

		for (size_t i = 0; i < surface->window_type_len; i++)
          if (surface->window_type[i] == get_netatom_n(NetWMWindowTypeDialog)
              || surface->window_type[i] == get_netatom_n(NetWMWindowTypeSplash)
              || surface->window_type[i] == get_netatom_n(NetWMWindowTypeToolbar)
              || surface->window_type[i] == get_netatom_n(NetWMWindowTypeUtility))
				return 1;

		return ((min.width > 0 || min.height > 0 || max.width > 0 || max.height > 0)
			&& (min.width == max.width || min.height == max.height))
			|| wlr_xwayland_surface_from_wlr_surface(CLIENT_SURFACE(c))->parent;
	}
#endif

	return ((min.width > 0 || min.height > 0 || max.width > 0 || max.height > 0)
		&& (min.width == max.width || min.height == max.height))
		|| wlr_xdg_surface_from_wlr_surface(CLIENT_SURFACE(c))->toplevel->parent;
}

SCM_DEFINE (gwwm_client_is_float_type_p,"client-is-float-type?",1,0,0,
            (SCM c),"")
#define FUNC_NAME s_gwwm_client_is_float_type_p
{
  GWWM_ASSERT_CLIENT_OR_FALSE(c ,1);
  return scm_from_bool(client_is_float_type(UNWRAP_CLIENT(c)));
}
#undef FUNC_NAME

bool
client_is_mapped(Client *c)
{
  PRINT_FUNCTION;
  return scm_to_bool(REF_CALL_1("gwwm client","client-mapped?",(WRAP_CLIENT(c))));
}

bool
client_wants_fullscreen(Client *c)
{
  PRINT_FUNCTION;
#ifdef XWAYLAND
	if (client_is_x11(c))
		return wlr_xwayland_surface_from_wlr_surface(CLIENT_SURFACE(c))->fullscreen;
#endif
	return wlr_xdg_surface_from_wlr_surface(CLIENT_SURFACE(c))->toplevel->requested.fullscreen;
}

bool
client_is_unmanaged(Client *c)
{
  return (scm_to_bool(REF_CALL_1("gwwm client","client-is-unmanaged?", WRAP_CLIENT(c))));
}

void
client_notify_enter(struct wlr_surface *s, struct wlr_keyboard *kb)
{
	if (kb)
      wlr_seat_keyboard_notify_enter(get_gloabl_seat(), s, kb->keycodes,
				kb->num_keycodes, &kb->modifiers);
	else
      wlr_seat_keyboard_notify_enter(get_gloabl_seat(), s, NULL, 0, NULL);
}

void
client_send_close(Client *c)
{
  REF_CALL_1("gwwm client","client-send-close" ,WRAP_CLIENT(c));
}

void
client_set_fullscreen(Client *c, bool fullscreen)
{
  scm_call_2(REFP("gwwm client","client-do-set-fullscreen"),
             WRAP_CLIENT(c),
             scm_from_bool(fullscreen));
}

void
client_set_tiled(Client *c, uint32_t edges)
{
  PRINT_FUNCTION;
  REF_CALL_2("gwwm client","client-set-tiled" ,WRAP_CLIENT(c), scm_from_uint32(edges));
}

struct wlr_surface *
client_surface_at(Client *c, double cx, double cy, double *sx, double *sy)
{
#ifdef XWAYLAND
	if (client_is_x11(c))
		return wlr_surface_surface_at(CLIENT_SURFACE(c),
				cx, cy, sx, sy);
#endif
	return wlr_xdg_surface_surface_at(wlr_xdg_surface_from_wlr_surface(CLIENT_SURFACE(c)), cx, cy, sx, sy);
}

void
client_restack_surface(Client *c)
{
#ifdef XWAYLAND
	if (client_is_x11(c))
		wlr_xwayland_surface_restack(wlr_xwayland_surface_from_wlr_surface(CLIENT_SURFACE(c)), NULL,
				XCB_STACK_MODE_ABOVE);
#endif
	return;
}
void
client_set_resizing(Client *c,bool resizing)
{
  REF_CALL_2("gwwm client","client-set-resizing!" ,WRAP_CLIENT(c), scm_from_bool(resizing));
}

SCM_DEFINE_PUBLIC (gwwm_client_at,"client-at",2,0,0,(SCM x, SCM y),""){
  Client *c=NULL;
  xytonode(scm_to_double(x), scm_to_double(y), NULL, &c, NULL, NULL, NULL);
  return c ? WRAP_CLIENT(c): SCM_BOOL_F;
}

SCM_DEFINE_PUBLIC(gwwm_client_from_popup,"client-from-popup",1,0,0,(SCM popup),"" ){
  Client *c=toplevel_from_popup(UNWRAP_WLR_XDG_POPUP(popup));
  return c? WRAP_CLIENT(c): SCM_BOOL_F;
}


Client *
toplevel_from_popup(struct wlr_xdg_popup *popup)
{
	struct wlr_xdg_surface *surface = popup->base;

	while (1) {
		switch (surface->role) {
		case WLR_XDG_SURFACE_ROLE_POPUP:
			if (wlr_surface_is_layer_surface(surface->popup->parent))
				return UNWRAP_CLIENT(wlr_layer_surface_v1_from_wlr_surface(surface->popup->parent)->data);
			else if (!wlr_surface_is_xdg_surface(surface->popup->parent))
				return NULL;

			surface = wlr_xdg_surface_from_wlr_surface(surface->popup->parent);
			break;
		case WLR_XDG_SURFACE_ROLE_TOPLEVEL:
				return UNWRAP_CLIENT(surface->data);
		case WLR_XDG_SURFACE_ROLE_NONE:
			return NULL;
		}
	}
}

SCM_DEFINE (gwwm_client_get_parent, "client-get-parent" ,1,0,0,
            (SCM c), "")
#define FUNC_NAME s_gwwm_client_get_parent
{
  GWWM_ASSERT_CLIENT_OR_FALSE(c ,1);
  Client *cl = UNWRAP_CLIENT(c);
  Client *p = client_get_parent(cl);
  if (p) {
    return WRAP_CLIENT(p);
  };
  return SCM_BOOL_F;
}
#undef FUNC_NAME

SCM_DEFINE (gwwm_client_wants_fullscreen_p , "client-wants-fullscreen?",1,0,0,
            (SCM client), "")
#define FUNC_NAME s_gwwm_client_wants_fullscreen_p
{
  GWWM_ASSERT_CLIENT_OR_FALSE(client ,1);
  return scm_from_bool(client_wants_fullscreen(UNWRAP_CLIENT(client)));
}
#undef FUNC_NAME

struct wlr_scene_rect *
client_fullscreen_bg(void *c , struct wlr_scene_rect *change) {
  PRINT_FUNCTION;
  SCM o;
  SCM sc=WRAP_CLIENT(c);
  if (change) {
    o=WRAP_WLR_SCENE_RECT(change);
    scm_slot_set_x(sc,scm_from_utf8_symbol("fullscreen-bg"),o);
    return change;
  } else {
    o=scm_slot_ref(sc, scm_from_utf8_symbol("fullscreen-bg"));
    return scm_is_false(o)? NULL : UNWRAP_WLR_SCENE_RECT(o);
  }
}

SCM_DEFINE_PUBLIC (gwwm_client_from_list,"gwwm-client-from-link",1,0,0,(SCM slink),""){
  struct wl_list *link=UNWRAP_WL_LIST(slink);
  Client *c;
  return WRAP_CLIENT(wl_container_of(link->next, c, link));
}

void
scm_init_gwwm_client(void)
{
#ifndef SCM_MAGIC_SNARFER
#include "client.x"
#endif
}
