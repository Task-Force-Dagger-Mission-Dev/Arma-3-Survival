params ["_vehicleClass","_loiterHeight","_loiterRadius","_defaultVehicleType"];

// verify vehicle has turrets that are not fire from vehicle and not copilot positions
// excludes fire from vehicle turrets
private _allVehicleTurrets = [_vehicleClass, false] call BIS_fnc_allTurrets;
// just turrets with weapons
private _turretsWithWeapons =  [];
private ["_turretWeapons_temp","_return_temp","_turretPath_temp"];
_allVehicleTurrets apply {
	_turretPath_temp = _x;
	_turretWeapons_temp = getArray([_vehicleClass,_turretPath_temp] call BIS_fnc_turretConfig >> "weapons");
	// if turrets are found
	if !(_turretWeapons_temp isEqualTo []) then {
		// some turrets are just optics, need to see they actually have ammo to shoot
		_return_temp = _turretWeapons_temp findIf {
			!([_x] call BIS_fnc_compatibleMagazines isEqualTo [])
		};
		if !(_return_temp isEqualTo -1) then {
			_turretsWithWeapons pushBack _turretPath_temp;
		};
	};
};
if (_turretsWithWeapons isEqualTo []) exitWith {
	[_defaultVehicleType] call BLWK_fnc_aircraftGunner;
};

// create vehicle
private _spawnPosition = [BLWK_playAreaMarker, true] call CBAP_fnc_randPosArea;
_spawnPosition set [2,_loiterHeight];
private _vehicleArray = [_spawnPosition,0,_vehicleClass,BLUFOR] call BIS_fnc_spawnVehicle;
private _vehicle = _vehicleArray select 0;
_vehicle allowDamage false;

// get rid of excess crew
private _vehicleCrew = _vehicleArray select 1;
_vehicleCrew apply {
	if ((_vehicle unitTurret _x) in _turretsWithWeapons) then {
		_vehicle deleteVehicleCrew _x
	} else {
		_x allowDamage false;
		_x disableAI "TARGET";
		_x disableAI "AUTOTARGET";
	};
};


// setup waypoints
private _vehicleGroup = _vehicleArray select 2;
_vehicleGroup setBehaviour "SAFE";
_vehicleGroup setCombatMode "BLUE";
private _loiterWaypoint = _vehicleGroup addWaypoint [BLWK_playAreaCenter,0];
_loiterWaypoint setWaypointType "LOITER";
_loiterWaypoint setWaypointLoiterRadius _loiterRadius;
_loiterWaypoint setWaypointLoiterType "CIRCLE_L";
_loiterWaypoint setWaypointLoiterAltitude _loiterHeight;
_vehicle flyInHeight _loiterHeight;
_loiterWaypoint setWaypointSpeed "LIMITED";


// handle view distances so things aren't cloudy
private _estimatedDistance = round (sqrt ((_loiterHeight^2) + (_loiterRadius^2)));
private _overallViewDistance = round (_estimatedDistance * 2.5);
private _objectViewDistance = round (_estimatedDistance * 1.5);
if (viewDistance < _overallViewDistance) then {
	setViewDistance _overallViewDistance;
};
if ((getObjectViewDistance select 0) < _objectViewDistance) then {
	setObjectViewDistance _objectViewDistance;
};
//hint str [_estimatedDistance,_overallViewDistance,_objectViewDistance];


// setup player interaction
BLWK_enforceArea = false;
[player,false] call BLWK_fnc_adjustStalkable; // make it so AI don't hunt the player
player allowDamage false;
player moveInTurret [_vehicle,_turretsWithWeapons select 0];
_vehicle enableCoPilot false; // disable the ability to take control of the aircraft

// create actions to switch turrets
private _turretSwitchActions = [];
private ["_turretAction_temp","_turretMagazines_temp","_turretPath_temp"];	
{
	_turretPath_temp = _x;

	_turretAction_temp = [	
		player,
		format ["<t color='#3c77ba'>Switch To Turret %1</t>",_forEachIndex + 1], 
		"\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_connect_ca.paa", 
		"\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_connect_ca.paa",
		["!(((objectParent player) turretUnit ",str _turretPath_temp,") isEqualTo player)"] joinString "", // check if units current turret is the stored one, don't show if it is
		"true", 
		{}, 
		{}, 
		{
			params ["_target", "_caller", "", "_arguments", "", ""];
			moveOut _caller;
			_caller moveInTurret [(_arguments select 0),_arguments select 1];
		}, 
		{}, 
		[_vehicle,_turretPath_temp], 
		0.5, 
		1, 
		false, 
		false, 
		false
	] call BIS_fnc_holdActionAdd;

	_turretSwitchActions pushBack _turretAction_temp;

	// give turrets a bit more ammo
	_turretMagazines_temp = _vehicle magazinesTurret _turretPath_temp;
	_turretMagazines_temp apply {
		_vehicle addMagazineTurret [_x,_turretPath_temp];
	};
} forEach _turretsWithWeapons;

// create action to exit the support and return to the bulwark
[	
	player,
	"<t color='#c91306'>Return To Bulwark</t>", 
	"\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_connect_ca.paa", 
	"\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_connect_ca.paa",
	"true",
	"true", 
	{}, 
	{}, 
	{
		params ["", "_caller", "_actionId", "_arguments", "", ""];

		setViewDistance -1;
		setObjectViewDistance -1;

		moveOut _caller;
		_caller setVehiclePosition [bulwarkBox,[],5,"NONE"];
		_caller setVelocity [0,0,0];
		[_caller,true] call BLWK_fnc_adjustStalkable;

		// add this action id to list of switch turret actions for removal
		private _actions = _arguments select 0;
		_actions pushBack _actionId;
		_actions apply {
			[_caller,_x] call BIS_fnc_holdActionRemove;
		};

		// delete vehicle
		private _vehicle = _arguments select 1;
		private _vehicleGroup = _arguments select 2;
		(units _vehicleGroup) apply {
			_vehicle deleteVehicleCrew _x;
		};
		deleteGroup _vehicleGroup;
		deleteVehicle _vehicle;
		
		null = [] spawn BLWK_fnc_playAreaEnforcementLoop;

		sleep 10;

		_caller allowDamage true;
	}, 
	{}, 
	[_turretSwitchActions,_vehicle,_vehicleGroup], 
	1, 
	1, 
	false, 
	false, 
	false
] call BIS_fnc_holdActionAdd;