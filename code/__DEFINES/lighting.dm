///Object doesn't use any of the light systems. Should be changed to add a light source to the object.
#define NO_LIGHT_SUPPORT 0
///Light made with the lighting datums, applying a matrix.
#define COMPLEX_LIGHT 1
///Light made by masking the lighting darkness plane.
#define OVERLAY_LIGHT 2
///Light made by masking the lighting darkness plane, and is directional.
#define OVERLAY_LIGHT_DIRECTIONAL 3

/// Is our overlay light source attached to another movable (its loc), meaning that the lighting component should go one level deeper.
#define LIGHT_ATTACHED (1<<0)

// Area lighting
/// Area is permanently black, cannot be lit ever. This shouldn't really be used, but is technically supported.
#define AREA_LIGHTING_NONE 0
/// Area is lit by lighting_object and lighting_sources
#define AREA_LIGHTING_DYNAMIC 1
/// Area is lit by the area's base_lighting values.
#define AREA_LIGHTING_STATIC 2

//Bay lighting engine shit, not in /code/modules/lighting because BYOND is being shit about it
/// frequency, in 1/10ths of a second, of the lighting process
#define LIGHTING_INTERVAL       5

#define MINIMUM_USEFUL_LIGHT_RANGE 1

/// height off the ground of light sources on the pseudo-z-axis, you should probably leave this alone
#define LIGHTING_HEIGHT         1
/// Value used to round lumcounts, values smaller than 1/129 don't matter (if they do, thanks sinking points), greater values will make lighting less precise, but in turn increase performance, VERY SLIGHTLY.
#define LIGHTING_ROUND_VALUE    (1 / 128)

/// icon used for lighting shading effects
#define LIGHTING_ICON 'icons/effects/lighting_object.dmi'

/// If the max of the lighting lumcounts of each spectrum drops below this, disable luminosity on the lighting objects.
/// Set to zero to disable soft lighting. Luminosity changes then work if it's lit at all.
#define LIGHTING_SOFT_THRESHOLD 0

///How many tiles standard fires glow.
#define LIGHT_RANGE_FIRE 3

#define LIGHTING_PLANE_ALPHA_VISIBLE 255
#define LIGHTING_PLANE_ALPHA_NV_TRAIT 245
#define LIGHTING_PLANE_ALPHA_MOSTLY_VISIBLE 192
/// For lighting alpha, small amounts lead to big changes. even at 128 its hard to figure out what is dark and what is light, at 64 you almost can't even tell.
#define LIGHTING_PLANE_ALPHA_MOSTLY_INVISIBLE 128
#define LIGHTING_PLANE_ALPHA_INVISIBLE 0

/// The amount of lumcount on a tile for it to be considered dark (used to determine reading and nyctophobia)
#define LIGHTING_TILE_IS_DARK 0.2

//code assumes higher numbers override lower numbers.
#define LIGHTING_NO_UPDATE 0
#define LIGHTING_VIS_UPDATE 1
#define LIGHTING_CHECK_UPDATE 2
#define LIGHTING_FORCE_UPDATE 3

#define FLASH_LIGHT_DURATION 2
#define FLASH_LIGHT_POWER 3
#define FLASH_LIGHT_RANGE 3.8

// Emissive blocking.
/// Uses vis_overlays to leverage caching so that very few new items need to be made for the overlay. For anything that doesn't change outline or opaque area much or at all.
#define EMISSIVE_BLOCK_GENERIC 1
/// Uses a dedicated render_target object to copy the entire appearance in real time to the blocking layer. For things that can change in appearance a lot from the base state, like humans.
#define EMISSIVE_BLOCK_UNIQUE 2

#define _EMISSIVE_COLOR(val) list(0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,1, val,val,val,0)

/// The color matrix applied to all emissive overlays. Should be solely dependent on alpha and not have RGB overlap with [EM_BLOCK_COLOR].
#define EMISSIVE_COLOR _EMISSIVE_COLOR(1)
/// A globaly cached version of [EMISSIVE_COLOR] for quick access.
GLOBAL_LIST_INIT(emissive_color, EMISSIVE_COLOR)

#define _EM_BLOCK_COLOR(val) list(0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,val, 0,0,0,0)
/// The color matrix applied to all emissive blockers. Should be solely dependent on alpha and not have RGB overlap with [EMISSIVE_COLOR].
#define EM_BLOCK_COLOR _EM_BLOCK_COLOR(1)

/// A globaly cached version of [EM_BLOCK_COLOR] for quick access.
GLOBAL_LIST_INIT(em_block_color, EM_BLOCK_COLOR)
/// A set of appearance flags applied to all emissive and emissive blocker overlays.
#define EMISSIVE_APPEARANCE_FLAGS (KEEP_APART|KEEP_TOGETHER|RESET_COLOR)
/// The color matrix used to mask out emissive blockers on the emissive plane. Alpha should default to zero, be solely dependent on the RGB value of [EMISSIVE_COLOR], and be independant of the RGB value of [EM_BLOCK_COLOR].
#define EM_MASK_MATRIX list(0,0,0,1/3, 0,0,0,1/3, 0,0,0,1/3, 0,0,0,0, 1,1,1,0)
/// A globaly cached version of [EM_MASK_MATRIX] for quick access.
GLOBAL_LIST_INIT(em_mask_matrix, EM_MASK_MATRIX)

/// Parse the hexadecimal color into lumcounts of each perspective.
#define PARSE_LIGHT_COLOR(source) \
do { \
	if (source.light_color != COLOR_WHITE) { \
		var/list/color_map = rgb2num(source.light_color); \
		source.lum_r = color_map[1] / 255; \
		source.lum_g = color_map[2] / 255; \
		source.lum_b = color_map[3] / 255; \
	} else { \
		source.lum_r = 1; \
		source.lum_g = 1; \
		source.lum_b = 1; \
	}; \
} while (FALSE)

/// The default falloff curve for all atoms. It's a magic number you should adjust until it looks good.
#define LIGHTING_DEFAULT_FALLOFF_CURVE 2

/// Include this to have lights randomly break on initialize.
#define LIGHTS_RANDOMLY_BROKEN

#define TURF_IS_DYNAMICALLY_LIT(T) (!(T.always_lit || T.loc.luminosity))

#define LIGHTBULB_COLOR_WHITE "#fefefe"
#define LIGHTBULB_COLOR_SLIGHTLY_WARM "#fffee0"
#define LIGHTBULB_COLOR_WARM "#dfac72"

// Machinery lights
///How much power emergency lights will consume per tick
#define LIGHT_EMERGENCY_POWER_USE 0.2
// status values shared between lighting fixtures and items
#define LIGHT_OK 0
#define LIGHT_EMPTY 1
#define LIGHT_BROKEN 2
#define LIGHT_BURNED 3

///Min time for a spark to happen in a broken light
#define BROKEN_SPARKS_MIN (3 MINUTES)
///Max time for a spark to happen in a broken light
#define BROKEN_SPARKS_MAX (9 MINUTES)

///Amount of time that takes an ethereal to take energy from the lights
#define LIGHT_DRAIN_TIME 2.5 SECONDS
///Amount of charge the ethereal gain after the drain
#define LIGHT_POWER_GAIN 35

///How many reagents the lights can hold
#define LIGHT_REAGENT_CAPACITY 5

//Status for light constructs
#define LIGHT_CONSTRUCT_EMPTY 1
#define LIGHT_CONSTRUCT_WIRED 2
#define LIGHT_CONSTRUCT_CLOSED 3
