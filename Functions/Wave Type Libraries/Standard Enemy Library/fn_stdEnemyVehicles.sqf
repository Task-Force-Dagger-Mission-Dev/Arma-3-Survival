#define LIKELIHOOD_HEAVY_ARMOUR 0.10
#define LIKELIHOOD_LIGHT_ARMOUR 0.15
#define LIKELIHOOD_HEAVY_CAR 0.25
#define LIKELIHOOD_LIGHT_CAR 0.50
#define BASE_VEHICLE_SPAWN_LIKELIHOOD 0.10
#define VEHICLE_SPAWN_INCRIMENT 0.05
#define ROUNDS_SINCE_MINUS_TWO(TOTAL_ROUNDS_SINCE) TOTAL_ROUNDS_SINCE - 2 


if (!local BLWK_theAIHandler) exitWith {false};

if !(BLWK_currentWaveNumber >= BLWK_vehicleStartWave) exitWith {false};

private _roundsSinceVehicleSpawned = missionNamespace getVariable ["BLWK_roundsSinceVehicleSpawned",2];
// wait until it has been at least two rounds since a vehicle spawn to get another one
if (_roundsSinceVehicleSpawned >= 2) exitWith {
	BLWK_roundsSinceVehicleSpawned = _roundsSinceVehicleSpawned + 1;
	false
};
	
// only the rounds after the two will contribute to the LIKELIHOOD percentage (5% per round, with a starting percentage of 10%)
private _howLikelyIsAVehicleToSpawn = (ROUNDS_SINCE_MINUS_TWO(_roundsSinceVehicleSpawned) * VEHICLE_SPAWN_INCRIMENT) + BASE_VEHICLE_SPAWN_LIKELIHOOD;
private _howLikelyIsAVheicleNOTToSpawn = 1 - _howLikelyIsAVehicleToSpawn;

private _vehcileWillSpawn = selectRandomWeighted [true,_howLikelyIsAVehicleToSpawn,false,_howLikelyIsAVheicleNOTToSpawn];
if !(_vehicleWillSpawn) exitWith {
	BLWK_roundsSinceVehicleSpawned = _roundsSinceVehicleSpawned + 1;
	false
};



missionNamespace setVariable ["BLWK_roundsSinceVehicleSpawned",0];
private _lightCarsArray = [];
private _heavyCarsArray = [];
private _lightArmourArray = [];
private _heavyArmourArray = [];
private _fn_checkLevelsClasses = {
	params ["_levelToCheck"];
	{
		if !(_x isEqualTo "") then {
			switch (_forEachIndex) do {
				case 0:{
					_lightCarsArray pushBack _x
				};
				case 1:{
					_heavyCarsArray pushBack _x
				};
				case 2:{
					_lightArmourArray pushBack _x
				};
				case 3:{
					_heavyArmourArray pushBack _x
				};
				default {};
			};
		};
	} forEach _levelToCheck;
};

// get all available vehicle types
[BLWK_level1_vehicleClasses] call _fn_checkLevelsClasses;
if (BLWK_currentWaveNumber > 5) then {
	[BLWK_level2_vehicleClasses] call _fn_checkLevelsClasses;
};
if (BLWK_currentWaveNumber > 10) then {
	[BLWK_level3_vehicleClasses] call _fn_checkLevelsClasses;
};
if (BLWK_currentWaveNumber > 15) then {
	[BLWK_level4_vehicleClasses] call _fn_checkLevelsClasses;
};
if (BLWK_currentWaveNumber > 20) then {
	[BLWK_level5_vehicleClasses] call _fn_checkLevelsClasses;
};

// get all available vehicle types
private _vehicleTypeSelection = [];
if !(_lightCarsArray isEqualTo []) then {
	_vehicleTypeSelection append [_lightCarsArray,LIKELIHOOD_LIGHT_CAR];
};
if !(_heavyCarsArray isEqualTo []) then {
	_vehicleTypeSelection append [_heavyCarsArray,LIKELIHOOD_HEAVY_CAR];
};
if !(_lightArmourArray isEqualTo []) then {
	_vehicleTypeSelection append [_lightArmourArray,LIKELIHOOD_LIGHT_ARMOUR];
};
if !(_heavyArmourArray isEqualTo []) then {
	_vehicleTypeSelection append [_heavyArmourArray,LIKELIHOOD_HEAVY_ARMOUR];
};


private _fn_spawnAVehicle = {
	private _selectedTypeArray = selectRandomWeighted _vehicleTypeSelection;
	private _selectedVehicleClass = selectRandom _selectedTypeArray;
	private _spawnPosition = selectRandom BLWK_vehicleSpawnPositions;
	private _createdVehicle = _selectedVehicleClass createVehicle _spawnPosition;
	
	_createdVehicle
};

call _fn_spawnAVehicle;



