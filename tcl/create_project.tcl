create_project ultrasound_meter ./build -part xc7z020clg400-1

add_files [glob ../rtl/*.sv]
add_files -fileset constrs_1 ../constraints/top.xdc

set_property top top_module [current_fileset]

update_compile_order -fileset sources_1
