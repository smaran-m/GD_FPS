## Known issues
- edge geometry
	- keep teleporting randomly
- rocket damage zone isn't instantiated when explosion is called
	- unclean, unoptimized
	- the area keeps moving after explode() and before queue_free()
	- can damage people through walls
- weapon switching is hard coded to pistol and RPG
	- _shoot_pistol calls hit(30) instead of using a damage value
