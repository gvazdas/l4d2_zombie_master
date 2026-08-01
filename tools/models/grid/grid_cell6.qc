$modelname "grid/grid_cell6.mdl"

$body "studio" "grid_cell5_ref.smd"

$surfaceprop "default"

$cdmaterials "models\\grid\\"

$bbox -16 -16 -4 16 16 4
$cbox -4096 -4096 -4096 4096 4096 4096

$texturegroup "skinfamilies"
{
	{ "grid_cell_valid" }
	{ "grid_cell_blocked2" }
	{ "grid_cell_conditional" }
	{ "grid_cell_target" }
	{ "grid_cell_ring" }
	{ "grid_cell_valid_xray" }
	{ "grid_cell_blocked2_xray" }
	{ "grid_cell_conditional_xray" }
	{ "grid_cell_seen" }
	{ "grid_cell_near" }
	{ "grid_cell_seen_xray" }
	{ "grid_cell_near_xray" }
}

$sequence "idle" "grid_cell5_ref.smd" fps 1
