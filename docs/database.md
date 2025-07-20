"""
[
{
"table_name": "onecup_glassware",
"columns": "id bigint, created_at timestamp with time zone, updated_at timestamp with time zone, name character varying"
},
{
"table_name": "onecup_ingredient_categories",
"columns": "id bigint, created_at timestamp with time zone, updated_at timestamp with time zone, name character varying"
},
{
"table_name": "onecup_ingredients",
"columns": "id bigint, created_at timestamp with time zone, updated_at timestamp with time zone, name character varying, category_id bigint, abv real, aliases ARRAY, taste character varying"
},
{
"table_name": "onecup_recipe_categories",
"columns": "id bigint, name character varying, created_at timestamp with time zone"
},
{
"table_name": "onecup_recipe_garnishes",
"columns": "id bigint, recipe_id bigint, item text, is_optional boolean, created_at timestamp with time zone"
},
{
"table_name": "onecup_recipe_glassware",
"columns": "id bigint, recipe_id bigint, glass_id bigint, created_at timestamp with time zone"
},
{
"table_name": "onecup_recipe_ingredients",
"columns": "id bigint, created_at timestamp with time zone, updated_at timestamp with time zone, recipe_id bigint, ingredient_id bigint, amount character varying, unit character varying, is_optional boolean, display_name character varying"
},
{
"table_name": "onecup_recipe_tags",
"columns": "id bigint, created_at timestamp with time zone, updated_at timestamp with time zone, recipe_id bigint, tag_id bigint"
},
{
"table_name": "onecup_recipes",
"columns": "id bigint, created_at timestamp with time zone, updated_at timestamp with time zone, name character varying, description text, instructions text, image character varying, source_id bigint, user_id uuid, notes ARRAY, video_url text, category_id bigint"
},
{
"table_name": "onecup_shopping_list",
"columns": "id bigint, created_at timestamp with time zone, updated_at bigint, ingredient_id bigint, user_id uuid, checked boolean"
},
{
"table_name": "onecup_sources",
"columns": "id bigint, created_at timestamp with time zone, updated_at timestamp without time zone, name character varying"
},
{
"table_name": "onecup_tags",
"columns": "id bigint, created_at timestamp with time zone, updated_at timestamp with time zone, name character varying"
},
{
"table_name": "onecup_user_favorites",
"columns": "id bigint, created_at timestamp with time zone, updated_at timestamp with time zone, user_id uuid, recipe_id bigint"
},
{
"table_name": "onecup_user_inventory",
"columns": "id bigint, created_at timestamp with time zone, updated_at timestamp with time zone, user_id uuid, ingredient_id bigint"
},
{
"table_name": "onecup_user_recipe_notes",
"columns": "id bigint, created_at timestamp with time zone, updated_at timestamp with time zone, user_id uuid, recipe_id bigint, notes text"
},
{
"table_name": "v_recipes_with_details",
"columns": "id bigint, created_at timestamp with time zone, updated_at timestamp with time zone, name character varying, description text, instructions text, image character varying, source_id bigint, user_id uuid, notes ARRAY, video_url text, category_id bigint, category_name character varying, glass_name character varying"
}
]
"""

