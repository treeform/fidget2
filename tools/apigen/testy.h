#include <stdbool.h>

typedef void (*proc_cb)();

bool fidget_input_code(long long a, long long b, long long c, long long d);
bool fidget_test_numbers(char a, unsigned char b, short c, unsigned short d, int e, unsigned int f, long long g, unsigned long long h, long long i, unsigned long long j, float k, double l, double m);
void fidget_call_me_maybe(char* phone);
char* fidget_flight_club_rule(long long n);
char* fidget_cat_str(char* a, char* b, char* c, char* d, char* e);

typedef struct Vector2 {
  float x;
  float y;
} Vector2;

void fidget_give_vec(Vector2 v);
Vector2 fidget_take_vec();

typedef struct Address {
  long long state;
  long long zip;
} Address;


typedef struct Contact {
  long long first_name;
  long long last_name;
  object
  state
  zip
 address;
} Contact;

Contact fidget_take_contact();

typedef long long Fod;
char* fidget_fod_get_name(Fod fod);
void fidget_fod_set_name(Fod fod, char* name);
long long fidget_fod_get_count(Fod fod);
void fidget_fod_set_count(Fod fod, long long count);

Fod fidget_take_fod();

typedef long long Boz;
char* fidget_boz_get_name(Boz boz);
void fidget_boz_set_name(Boz boz, char* name);
Fod fidget_boz_get_fod(Boz boz);
void fidget_boz_set_fod(Boz boz, Fod fod);

Boz fidget_take_boz();

typedef long long AlignSomething;
#define AS_DEFAULT 0
#define AS_TOP 1
#define AS_BOTTOM 2
#define AS_RIGHT 3
#define AS_LEFT 4
AlignSomething fidget_repeat_enum(AlignSomething e);
void fidget_call_me_back(proc_cb cb);
uint64 fidget_take_seq();
void fidget_give_seq(uint64 s);
void fidget_give_seq_of_vector2(Vector2 s);
Vector2 fidget_take_seq_of_vector2();
void fidget_give_seq_of_boz(Boz s);
Boz fidget_take_seq_of_boz();

typedef long long TextCase;
#define TC_NORMAL 0
#define TC_UPPER 1
#define TC_LOWER 2
#define TC_TITLE 3

typedef long long PaintKind;
#define PK_SOLID 0
#define PK_IMAGE 1
#define PK_IMAGE_TILED 2
#define PK_GRADIENT_LINEAR 3
#define PK_GRADIENT_RADIAL 4
#define PK_GRADIENT_ANGULAR 5

typedef long long BlendMode;
#define BM_NORMAL 0
#define BM_DARKEN 1
#define BM_MULTIPLY 2
#define BM_COLOR_BURN 3
#define BM_LIGHTEN 4
#define BM_SCREEN 5
#define BM_COLOR_DODGE 6
#define BM_OVERLAY 7
#define BM_SOFT_LIGHT 8
#define BM_HARD_LIGHT 9
#define BM_DIFFERENCE 10
#define BM_EXCLUSION 11
#define BM_HUE 12
#define BM_SATURATION 13
#define BM_COLOR 14
#define BM_LUMINOSITY 15
#define BM_MASK 16
#define BM_OVERWRITE 17
#define BM_SUBTRACT_MASK 18
#define BM_EXCLUDE_MASK 19

typedef struct ColorRGBX {
  unsigned char r;
  unsigned char g;
  unsigned char b;
  unsigned char a;
} ColorRGBX;


typedef struct ColorStop2 {
  object
  r
  g
  b
  a
 color;
  float position;
} ColorStop2;


typedef struct Paint2 {
  enum
  pkSolid, pkImage, pkImageTiled, pkGradientLinear, pkGradientRadial,
  pkGradientAngular kind;
  enum
  bmNormal, bmDarken, bmMultiply, bmColorBurn, bmLighten, bmScreen,
  bmColorDodge, bmOverlay, bmSoftLight, bmHardLight, bmDifference, bmExclusion,
  bmHue, bmSaturation, bmColor, bmLuminosity, bmMask, bmOverwrite,
  bmSubtractMask, bmExcludeMask blend_mode;
  ColorStop2 gradient_stops;
} Paint2;


typedef long long Typeface2;
char* fidget_typeface2_get_file_path(Typeface2 typeface2);
void fidget_typeface2_set_file_path(Typeface2 typeface2, char* file_path);


typedef long long Font2;
Typeface2 fidget_font2_get_typeface(Font2 font2);
void fidget_font2_set_typeface(Font2 font2, Typeface2 typeface);
float fidget_font2_get_size(Font2 font2);
void fidget_font2_set_size(Font2 font2, float size);
float fidget_font2_get_line_height(Font2 font2);
void fidget_font2_set_line_height(Font2 font2, float line_height);
object
  kind
  blendMode
  gradientStops
 fidget_font2_get_paint(Font2 font2);
void fidget_font2_set_paint(Font2 font2, object
  kind
  blendMode
  gradientStops
 paint);
enum
  tcNormal, tcUpper, tcLower, tcTitle fidget_font2_get_text_case(Font2 font2);
void fidget_font2_set_text_case(Font2 font2, enum
  tcNormal, tcUpper, tcLower, tcTitle text_case);
bool fidget_font2_get_underline(Font2 font2);
void fidget_font2_set_underline(Font2 font2, bool underline);
bool fidget_font2_get_strikethrough(Font2 font2);
void fidget_font2_set_strikethrough(Font2 font2, bool strikethrough);
bool fidget_font2_get_no_kerning_adjustments(Font2 font2);
void fidget_font2_set_no_kerning_adjustments(Font2 font2, bool no_kerning_adjustments);

Font2 fidget_read_font2(char* font_path);
