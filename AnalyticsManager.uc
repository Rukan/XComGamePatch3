//---------------------------------------------------------------------------------------
//  FILE:    AnalyticsManager.uc
//  AUTHOR:  Scott Ramsay  --  4/6/2015
//  PURPOSE: Global manager
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------
class AnalyticsManager extends Object
	native(Core)
	dependson(X2StrategyGameRulesetDataStructures, XComGameState);

// data duped from XComGameState_CampaignSettings
struct native CampaignSettings
{
	var string StartTime;					// Tracks when the player initiated this campaign.
	var int DifficultySetting;				// 0:Easy 1:Normal 2:Classic 3:Impossible
	var bool bIronmanEnabled;				// TRUE indicates that this campaign was started with Ironman enabled
	var bool bTutorialEnabled;				// TRUE indicates that this campaign was started with the tutorial enabled
	var bool bSuppressFirstTimeNarrative;	// TRUE, the tutorial narrative moments will be skipped
};

var private{private} bool bShouldSubmitGameState;

var private{private} bool bAvaibleWorldStats;
var private{private} bool bWaitingOnWorldStats;

var private native Map_Mirror GlobalEndgameStats{ TMap<FName, double> };
var private int NumEndgameStatSubmissions;

var XComGameState_Analytics		PrevDebugAnalytics;

native function Init();

private native function SendCampaignAnalytics(out CampaignSettings Settings, array<XComGameState_Unit> Units);

function bool ShouldSubmitGameState()
{
	return bShouldSubmitGameState;
}

function SendCampaign()
{
	local XComGameState_CampaignSettings Settings;
	local XComGameState_HeadquartersXCom XComHQ;
	local CampaignSettings Info;
	local XComGameStateHistory History;
	local StateObjectReference ObjRef;
	local XComGameState_Unit Unit;
	local array<XComGameState_Unit> Units;

	History = `XCOMHISTORY;
	Settings = XComGameState_CampaignSettings(History.GetSingleGameStateObjectForClass(class'XComGameState_CampaignSettings'));
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));

	// pull metric data from XComGameState_CampaignSettings
	Info.StartTime = Settings.StartTime;
	Info.DifficultySetting = Settings.DifficultySetting;
	Info.bIronmanEnabled = Settings.bIronmanEnabled;
	Info.bTutorialEnabled = Settings.bTutorialEnabled;
	Info.bSuppressFirstTimeNarrative = Settings.bSuppressFirstTimeNarrative;

	// extract unit meta info
	foreach XComHQ.Crew(ObjRef)
	{
		Unit = XComGameState_Unit(History.GetGameStateForObjectID( ObjRef.ObjectID ));
		if (Unit.IsSoldier())
		{
			Units.AddItem( Unit );
		}
	}

	SendCampaignAnalytics(Info, Units);
}

native static function SendCampaignEndGame( );

function DebugDoEndgameStats( bool Win )
{
	local X2FiraxisLiveClient LiveClient;

	if (Win)
		SendCampaignEndGame( );

	LiveClient = `FXSLIVE;

	bAvaibleWorldStats = false;
	bWaitingOnWorldStats = true;
	LiveClient.AddReceivedStatsKVPDelegate( StatsRecieved );

	LiveClient.GetStats( eKVPSCOPE_GLOBAL );
}

static function bool SkipAddAnalyticObject(XComGameState GameState)
{
	local XComGameState_BattleData Battle;
	Battle = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData', true));

	// Don't add any objects while in Multiplayer
	if( Battle == none || Battle.m_strDesc ~= "Multiplayer" )
	{
		return true;
	}

	// Don't add objects for interrupted gamestates.  Only create analytics for completed (none or resume contexts)
	if (GameState.GetContext().InterruptionStatus == eInterruptionStatus_Interrupt)
	{
		return true;
	}

	return false;
}


static function EventListenerReturn OnSoldierTacticalToStrategy(Object EventData, Object EventSource, XComGameState GameState, Name EventID)
{
	local XComGameState_Analytics AnalyticsObject;
	local XComGameStateHistory History;

	if (SkipAddAnalyticObject(GameState))
	{
		return ELR_NoInterrupt;
	}

	History = `XCOMHISTORY;

	// check if we have analytics object
	AnalyticsObject = XComGameState_Analytics(History.GetSingleGameStateObjectForClass(class'XComGameState_Analytics', true));
	if (AnalyticsObject != none)
	{
		AnalyticsObject.AddSoldierTacticalToStrategy(XComGameState_Unit(EventData), GameState);
	}

	return ELR_NoInterrupt;
}

static function EventListenerReturn OnTacticalGameStart(Object EventData, Object EventSource, XComGameState GameState, Name EventID)
{
	local XComGameState_Analytics AnalyticsObject;
	local XComGameStateHistory History;

	if (SkipAddAnalyticObject( GameState ))
	{
		return ELR_NoInterrupt;
	}

	History = `XCOMHISTORY;

	// check if we have analytics object
	AnalyticsObject = XComGameState_Analytics( History.GetSingleGameStateObjectForClass( class'XComGameState_Analytics', true ) );
	if (AnalyticsObject != none)
	{
		AnalyticsObject.AddTacticalGameStart( );
	}

	return ELR_NoInterrupt;
}

static function EventListenerReturn OnTacticalGameEnd(Object EventData, Object EventSource, XComGameState GameState, Name EventID)
{
	local XComGameState_Analytics AnalyticsObject;
	local XComGameStateHistory History;

	if (SkipAddAnalyticObject(GameState))
	{
		return ELR_NoInterrupt;
	}

	History = `XCOMHISTORY;

	// check if we have analytics object
	AnalyticsObject = XComGameState_Analytics(History.GetSingleGameStateObjectForClass(class'XComGameState_Analytics', true));
	if (AnalyticsObject != none)
	{
		AnalyticsObject.AddTacticalGameEnd();
	}

	return ELR_NoInterrupt;
}

static function EventListenerReturn OnPlayerTurnEnded( Object EventData, Object EventSource, XComGameState GameState, Name EventID )
{
	local XComGameState_Analytics AnalyticsObject;
	local XComGameStateHistory History;

	if (SkipAddAnalyticObject( GameState ))
	{
		return ELR_NoInterrupt;
	}

	History = `XCOMHISTORY;

	// check if we have analytics object
	AnalyticsObject = XComGameState_Analytics( History.GetSingleGameStateObjectForClass( class'XComGameState_Analytics', true ) );
	if ((AnalyticsObject != none) && (XComGameState_Player(EventData).TeamFlag == eTeam_XCom))
	{
		AnalyticsObject.AddPlayerTurnEnd( );
	}

	return ELR_NoInterrupt;
}

static function EventListenerReturn OnUnitMoved(Object EventData, Object EventSource, XComGameState GameState, Name EventID)
{
	local XComGameState_Analytics AnalyticsObject;
	local XComGameStateHistory History;

	if (SkipAddAnalyticObject( GameState ))
	{
		return ELR_NoInterrupt;
	}

	History = `XCOMHISTORY;

	// check if we have analytics object
	AnalyticsObject = XComGameState_Analytics( History.GetSingleGameStateObjectForClass( class'XComGameState_Analytics', true ) );
	if (AnalyticsObject != none)
	{
		// report move
		AnalyticsObject.AddUnitMoved( XComGameState_Unit( EventSource ) );
	}

	return ELR_NoInterrupt;
}

static function EventListenerReturn OnKillMail(Object EventData, Object EventSource, XComGameState GameState, Name EventID)
{
	local XComGameState_Analytics AnalyticsObject;
	local XComGameStateHistory History;

	if( SkipAddAnalyticObject(GameState) )
	{
		return ELR_NoInterrupt;
	}

	`ANALYTICSLOG("KillMail");

	History = `XCOMHISTORY;

	// check if we have analytics object
	AnalyticsObject = XComGameState_Analytics(History.GetSingleGameStateObjectForClass(class'XComGameState_Analytics', true));
	if (AnalyticsObject != none)
	{
		// report kill
		AnalyticsObject.AddKillMail(XComGameState_Unit(EventSource), XComGameState_Unit(EventData));
	}

	return ELR_NoInterrupt;
}


static function EventListenerReturn OnBreakWindow(Object EventData, Object EventSource, XComGameState GameState, Name EventID)
{
	local XComGameState_Analytics AnalyticsObject;
	local XComGameStateHistory History;

	if( SkipAddAnalyticObject(GameState) )
	{
		return ELR_NoInterrupt;
	}

	`ANALYTICSLOG("BreakWindow");

	History = `XCOMHISTORY;

	// check if we have analytics object
	AnalyticsObject = XComGameState_Analytics(History.GetSingleGameStateObjectForClass(class'XComGameState_Analytics', true));
	if (AnalyticsObject != none)
	{
		AnalyticsObject.AddBreakWindow(XComGameState_Unit(EventSource), XComGameStateContext_Ability(EventData));
	}

	return ELR_NoInterrupt;
}


static function EventListenerReturn OnBreakDoor(Object EventData, Object EventSource, XComGameState GameState, Name EventID)
{
	local XComGameState_Analytics AnalyticsObject;
	local XComGameStateHistory History;

	if( SkipAddAnalyticObject(GameState) )
	{
		return ELR_NoInterrupt;
	}

	`ANALYTICSLOG("BreakDoor");

	History = `XCOMHISTORY;

	// check if we have analytics object
	AnalyticsObject = XComGameState_Analytics(History.GetSingleGameStateObjectForClass(class'XComGameState_Analytics', true));
	if (AnalyticsObject != none)
	{
		AnalyticsObject.AddBreakDoor(XComGameState_Unit(EventSource), XComGameStateContext_Ability(EventData));
	}

	return ELR_NoInterrupt;
}


static function EventListenerReturn OnWeaponKillType(Object EventData, Object EventSource, XComGameState GameState, Name EventID)
{
	local XComGameState_Analytics AnalyticsObject;
	local XComGameStateHistory History;

	if( SkipAddAnalyticObject(GameState) )
	{
		return ELR_NoInterrupt;
	}

	`ANALYTICSLOG("Weapon Kill Type");

	History = `XCOMHISTORY;

	// check if we have analytics object
	AnalyticsObject = XComGameState_Analytics(History.GetSingleGameStateObjectForClass(class'XComGameState_Analytics', true));
	if (AnalyticsObject != none)
	{
		AnalyticsObject.AddWeaponKill(XComGameState_Unit(EventSource), XComGameState_Ability(EventData));
	}

	return ELR_NoInterrupt;
}

static function EventListenerReturn OnMissionObjectiveComplete(Object EventData, Object EventSource, XComGameState GameState, Name EventID)
{
	local XComGameState_Analytics AnalyticsObject;
	local XComGameStateHistory History;

	if (SkipAddAnalyticObject(GameState))
	{
		return ELR_NoInterrupt;
	}

	`ANALYTICSLOG("Mission Objective Complete");

	History = `XCOMHISTORY;

	// check if we have analytics object
	AnalyticsObject = XComGameState_Analytics(History.GetSingleGameStateObjectForClass(class'XComGameState_Analytics', true));
	if (AnalyticsObject != none)
	{
		AnalyticsObject.AddMissionObjectiveComplete();
	}

	return ELR_NoInterrupt;
}

static function EventListenerReturn OnCivilianRescued(Object EventData, Object EventSource, XComGameState GameState, Name EventID)
{
	local XComGameState_Analytics AnalyticsObject;
	local XComGameStateHistory History;

	if (SkipAddAnalyticObject(GameState))
	{
		return ELR_NoInterrupt;
	}

	`ANALYTICSLOG("Civilian Rescued");

	History = `XCOMHISTORY;

	// check if we have analytics object
	AnalyticsObject = XComGameState_Analytics(History.GetSingleGameStateObjectForClass(class'XComGameState_Analytics', true));
	if (AnalyticsObject != none)
	{
		AnalyticsObject.AddCivilianRescued(XComGameState_Unit(EventData), XComGameState_Unit(EventSource));
	}

	return ELR_NoInterrupt;
}

static function EventListenerReturn OnUnitDamaged(Object EventData, Object EventSource, XComGameState GameState, Name EventID)
{
	local XComGameState_Analytics AnalyticsObject;
	local XComGameStateHistory History;
	local XComGameStateContext_Ability AbilityContext;
	local XComGameState_Unit DamageSource;

	if (SkipAddAnalyticObject( GameState ))
	{
		return ELR_NoInterrupt;
	}

	History = `XCOMHISTORY;

	// check if we have analytics object
	AnalyticsObject = XComGameState_Analytics( History.GetSingleGameStateObjectForClass( class'XComGameState_Analytics', true ) );
	if (AnalyticsObject != none)
	{
		AbilityContext = XComGameStateContext_Ability( GameState.GetContext() );
		if (AbilityContext != none)
		{
			DamageSource = XComGameState_Unit(History.GetGameStateForObjectID(AbilityContext.InputContext.SourceObject.ObjectID));
		}

		AnalyticsObject.AddUnitDamage( XComGameState_Unit( EventSource ), DamageSource, GameState.GetContext() );
	}

	return ELR_NoInterrupt;
}

static function EventListenerReturn OnAbilityActivation(Object EventData, Object EventSource, XComGameState GameState, Name EventID)
{
	local XComGameState_Analytics AnalyticsObject;
	local XComGameStateHistory History;
	local XComGameStateContext_Ability AbilityContext;
	local XComGameState_Unit Shooter, Target;
	local XComGameState_Item Tool;

	if (SkipAddAnalyticObject( GameState ))
	{
		return ELR_NoInterrupt;
	}

	History = `XCOMHISTORY;

	// check if we have analytics object
	AnalyticsObject = XComGameState_Analytics( History.GetSingleGameStateObjectForClass( class'XComGameState_Analytics', true ) );
	if (AnalyticsObject != none)
	{
		AbilityContext = XComGameStateContext_Ability( GameState.GetContext( ) );
		`assert( AbilityContext != none );

		Shooter = XComGameState_Unit(History.GetGameStateForObjectID(AbilityContext.InputContext.SourceObject.ObjectID));
		Target = XComGameState_Unit(History.GetGameStateForObjectID(AbilityContext.InputContext.PrimaryTarget.ObjectID));
		Tool = XComGameState_Item(History.GetGameStateForObjectID(AbilityContext.InputContext.ItemObject.ObjectID));

		AnalyticsObject.AddUnitTakenShot( Shooter, Target, Tool, AbilityContext, XComGameState_Ability(EventData) );
	}

	return ELR_NoInterrupt;
}

static function EventListenerReturn OnUnitHealComplete(Object EventData, Object EventSource, XComGameState GameState, Name EventID)
{
	local XComGameState_Analytics AnalyticsObject;
	local XComGameStateHistory History;
	local XComGameState_HeadquartersProjectHealSoldier HealProject;
	local XComGameState_Unit UnitState;
	local TDateTime CurrentDate;
	local int TimeDiffHours;

	if (SkipAddAnalyticObject( GameState ))
	{
		return ELR_NoInterrupt;
	}

	History = `XCOMHISTORY;

	// check if we have analytics object
	AnalyticsObject = XComGameState_Analytics( History.GetSingleGameStateObjectForClass( class'XComGameState_Analytics', true ) );
	if (AnalyticsObject != none)
	{
		UnitState = XComGameState_Unit( EventData );
		HealProject = XComGameState_HeadquartersProjectHealSoldier( EventSource );
		CurrentDate = `STRATEGYRULES.GameTime;

		TimeDiffHours =  class'X2StrategyGameRulesetDataStructures'.static.DifferenceInHours( CurrentDate, HealProject.TrueStart );

		AnalyticsObject.AddUnitHealCompleted( UnitState, TimeDiffHours );
	}

	return ELR_NoInterrupt;
}

static function EventListenerReturn OnNewCrewAdded( Object EventData, Object EventSource, XComGameState GameState, Name EventID )
{
	local XComGameState_Analytics AnalyticsObject;
	local XComGameStateHistory History;

	if (SkipAddAnalyticObject( GameState ))
	{
		return ELR_NoInterrupt;
	}

	History = `XCOMHISTORY;

	// check if we have analytics object
	AnalyticsObject = XComGameState_Analytics( History.GetSingleGameStateObjectForClass( class'XComGameState_Analytics', true ) );
	if (AnalyticsObject != none)
	{
		AnalyticsObject.AddCrewAddition( XComGameState_Unit(EventData) );
	}

	return ELR_NoInterrupt;
}

static function EventListenerReturn OnResearchCompleted( Object EventData, Object EventSource, XComGameState GameState, Name EventID )
{
	local XComGameState_Analytics AnalyticsObject;
	local XComGameStateHistory History;

	if (SkipAddAnalyticObject( GameState ))
	{
		return ELR_NoInterrupt;
	}

	History = `XCOMHISTORY;

	// check if we have analytics object
	AnalyticsObject = XComGameState_Analytics( History.GetSingleGameStateObjectForClass( class'XComGameState_Analytics', true ) );
	if (AnalyticsObject != none)
	{
		AnalyticsObject.AddResearchCompletion( XComGameState_Tech( EventData ) );
	}

	return ELR_NoInterrupt;
}

static function EventListenerReturn OnResistanceActivityComplete( Object EventData, Object EventSource, XComGameState GameState, Name EventID )
{
	local XComGameState_Analytics AnalyticsObject;
	local XComGameStateHistory History;
	local X2ResistanceActivityTemplate ActivityTemplate;
	local XComGameState_HeadquartersResistance ResistanceHQ;
	local int Delta, idx;

	if (SkipAddAnalyticObject( GameState ))
	{
		return ELR_NoInterrupt;
	}

	History = `XCOMHISTORY;

	// check if we have analytics object
	AnalyticsObject = XComGameState_Analytics( History.GetSingleGameStateObjectForClass( class'XComGameState_Analytics', true ) );
	if (AnalyticsObject != none)
	{
		ActivityTemplate = X2ResistanceActivityTemplate( EventData );
		ResistanceHQ = XComGameState_HeadquartersResistance( EventSource );

		idx = ResistanceHQ.ResistanceActivities.Find('ActivityTemplateName', ActivityTemplate.Name );
		Delta = ResistanceHQ.ResistanceActivities[idx].LastIncrement;

		AnalyticsObject.AddResistanceActivity( ActivityTemplate, Delta );
	}

	return ELR_NoInterrupt;
}

static function EventListenerReturn OnResourceAdded( Object EventData, Object EventSource, XComGameState GameState, Name EventID )
{
	local XComGameState_Analytics AnalyticsObject;
	local XComGameStateHistory History;
	local XComGameState_Item Resource;
	
	if (SkipAddAnalyticObject( GameState ))
	{
		return ELR_NoInterrupt;
	}

	History = `XCOMHISTORY;

	// check if we have analytics object
	AnalyticsObject = XComGameState_Analytics( History.GetSingleGameStateObjectForClass( class'XComGameState_Analytics', true ) );
	if (AnalyticsObject != none)
	{
		Resource = XComGameState_Item( EventData );

		AnalyticsObject.AddResource( Resource, Resource.LastQuantityChange );
	}

	return ELR_NoInterrupt;
}

static function EventListenerReturn OnBlackMarketPurchase( Object EventData, Object EventSource, XComGameState GameState, Name EventID )
{
	local XComGameState_Analytics AnalyticsObject;
	local XComGameStateHistory History;
	local XComGameState_BlackMarket BlackMarket;
	local XComGameState_Reward RewardState;

	if (SkipAddAnalyticObject( GameState ))
	{
		return ELR_NoInterrupt;
	}

	History = `XCOMHISTORY;

	// check if we have analytics object
	AnalyticsObject = XComGameState_Analytics( History.GetSingleGameStateObjectForClass( class'XComGameState_Analytics', true ) );
	if (AnalyticsObject != none)
	{
		RewardState = XComGameState_Reward( EventData );
		BlackMarket = XComGameState_BlackMarket( History.GetPreviousGameStateForObject( XComGameState_BlackMarket( EventSource ) ) );

		AnalyticsObject.AddBlackMarketPurchase( BlackMarket, RewardState );
	}

	return ELR_NoInterrupt;
}

static function EventListenerReturn OnBlackMarketGoodsSold( Object EventData, Object EventSource, XComGameState GameState, Name EventID )
{
	local XComGameState_Analytics AnalyticsObject;
	local XComGameStateHistory History;
	local StateObjectReference ObjRef;
	local XComGameState_Item ItemState, PrevState;
	local XComGameState_HeadquartersXCom XComHQ;
	local int Supplies, PrevSupplies;

	if (SkipAddAnalyticObject( GameState ))
	{
		return ELR_NoInterrupt;
	}

	History = `XCOMHISTORY;

	// check if we have analytics object
	AnalyticsObject = XComGameState_Analytics( History.GetSingleGameStateObjectForClass( class'XComGameState_Analytics', true ) );
	if (AnalyticsObject != none)
	{
		XComHQ = XComGameState_HeadquartersXCom( History.GetSingleGameStateObjectForClass( class'XComGameState_HeadquartersXCom' ) );
		foreach XComHQ.Inventory(ObjRef)
		{
			ItemState = XComGameState_Item( History.GetGameStateForObjectID( ObjRef.ObjectID ) );

			if (ItemState != none && ItemState.GetMyTemplateName( ) == 'Supplies')
			{
				break;
			}
		}

		PrevState = XComGameState_Item( History.GetPreviousGameStateForObject( ItemState ) );

		Supplies = ItemState.Quantity;
		PrevSupplies = PrevState.Quantity;

		AnalyticsObject.AddBlackmarketSupplies( Supplies - PrevSupplies );
	}

	return ELR_NoInterrupt;
}

static function EventListenerReturn OnSupplyDrop( Object EventData, Object EventSource, XComGameState GameState, Name EventID )
{
	local XComGameState_Analytics AnalyticsObject;
	local XComGameStateHistory History;
	local StateObjectReference ObjRef;
	local XComGameState_Item ItemState, PrevState;
	local XComGameState_HeadquartersXCom XComHQ;
	local int Supplies, PrevSupplies;

	if (SkipAddAnalyticObject( GameState ))
	{
		return ELR_NoInterrupt;
	}

	History = `XCOMHISTORY;

	// check if we have analytics object
	AnalyticsObject = XComGameState_Analytics( History.GetSingleGameStateObjectForClass( class'XComGameState_Analytics', true ) );
	if (AnalyticsObject != none)
	{
		XComHQ = XComGameState_HeadquartersXCom( History.GetGameStateForObjectID( XComGameState_BaseObject(EventData).ObjectID ) );
		foreach XComHQ.Inventory(ObjRef)
		{
			ItemState = XComGameState_Item( History.GetGameStateForObjectID( ObjRef.ObjectID ) );

			if (ItemState != none && ItemState.GetMyTemplateName( ) == 'Supplies')
			{
				break;
			}
		}

		PrevState = XComGameState_Item( History.GetPreviousGameStateForObject( ItemState ) );

		Supplies = ItemState.Quantity;
		PrevSupplies = PrevState.Quantity;

		AnalyticsObject.AddSupplyDropSupplies( Supplies - PrevSupplies );
	}

	return ELR_NoInterrupt;
}

native function StatsRecieved( bool Success, array<string> GlobalKeys, array<int> GlobalValues, array<string> UserKeys, array<int> UserValues );
private native function string NativeGetAvgWorldStatValueAsString( name metric, string Default = "0" ) const;
private native function double NativeGetAvgWorldStatValue( name metric ) const;
private native function float NativeGetAvgWorldStatFloatValue( name metric ) const; // Unrealscript has trouble converting from double to float.  This works around the compiler issue.

function string GetAvgWorldStatValueAsString( name metric, string DefaultVal = "0" )
{
	return NativeGetAvgWorldStatValueAsString( class'XComGameState_Analytics'.static.BuildEndGameMetric( metric ), DefaultVal );
}

function double GetAvgWorldStatValue( name metric )
{
	return NativeGetAvgWorldStatValue( class'XComGameState_Analytics'.static.BuildEndGameMetric( metric ) );
}

function float GetAvgWorldStatFloatValue( name metric )
{
	return NativeGetAvgWorldStatFloatValue( class'XComGameState_Analytics'.static.BuildEndGameMetric( metric ) );
}

private native function string NativeGetWorldStatValueAsString( name metric, string Default = "0" ) const;
private native function double NativeGetWorldStatValue( name metric ) const;
private native function float NativeGetWorldStatFloatValue( name metric ) const; // Unrealscript has trouble converting from double to float.  This works around the compiler issue.

function string GetWorldStatValueAsString( name metric, string DefaultVal = "0" )
{
	return NativeGetWorldStatValueAsString( class'XComGameState_Analytics'.static.BuildEndGameMetric( metric ), DefaultVal );
}

function double GetWorldStatValue( name metric )
{
	return NativeGetWorldStatValue( class'XComGameState_Analytics'.static.BuildEndGameMetric( metric ) );
}

function float GetWorldStatFloatValue( name metric )
{
	return NativeGetWorldStatFloatValue( class'XComGameState_Analytics'.static.BuildEndGameMetric( metric ) );
}

function bool WaitingOnWorldStats( )
{
	return bWaitingOnWorldStats;
}

function bool WorldStatsAvailable( )
{
	return !bWaitingOnWorldStats && bAvaibleWorldStats;
}

static function EventListenerReturn OnVictory( Object EventData, Object EventSource, XComGameState GameState, Name EventID )
{
	local XComGameState_Analytics AnalyticsObject;
	local XComGameStateHistory History;
	local X2FiraxisLiveClient LiveClient;

	if (SkipAddAnalyticObject( GameState ))
	{
		return ELR_NoInterrupt;
	}

	History = `XCOMHISTORY;

	// check if we have analytics object
	AnalyticsObject = XComGameState_Analytics( History.GetSingleGameStateObjectForClass( class'XComGameState_Analytics', true ) );
	if (AnalyticsObject != none)
	{
		AnalyticsObject.AddXComVictory( );

		SendCampaignEndGame( );

		LiveClient = `FXSLIVE;

		`XANALYTICS.bAvaibleWorldStats = false;
		`XANALYTICS.bWaitingOnWorldStats = true;
		LiveClient.AddReceivedStatsKVPDelegate( `XANALYTICS.StatsRecieved );

		LiveClient.GetStats( eKVPSCOPE_GLOBAL );
	}

	return ELR_NoInterrupt;
}

static function EventListenerReturn OnLoss( Object EventData, Object EventSource, XComGameState GameState, Name EventID )
{
	local X2FiraxisLiveClient LiveClient;

	if (SkipAddAnalyticObject( GameState ))
	{
		return ELR_NoInterrupt;
	}

	LiveClient = `FXSLIVE;

	`XANALYTICS.bAvaibleWorldStats = false;
	`XANALYTICS.bWaitingOnWorldStats = true;
	LiveClient.AddReceivedStatsKVPDelegate( `XANALYTICS.StatsRecieved );

	LiveClient.GetStats( eKVPSCOPE_GLOBAL );

	return ELR_NoInterrupt;
}

function CancelWorldStats( )
{
	local X2FiraxisLiveClient LiveClient;

	bWaitingOnWorldStats = false;

	LiveClient = `FXSLIVE;
	LiveClient.ClearReceivedStatsKVPDelegate( StatsRecieved );
}

event CloseWorldStatsDialog()
{
	`HQPRES.UICloseProgressDialog();
}

static function EventListenerReturn OnUnitPromotion( Object EventData, Object EventSource, XComGameState GameState, Name EventID )
{
	local XComGameState_Analytics AnalyticsObject;
	local XComGameStateHistory History;
	local XComGameState_Unit UnitState, PrevUnitState;

	if (SkipAddAnalyticObject( GameState ))
	{
		return ELR_NoInterrupt;
	}

	History = `XCOMHISTORY;

	// check if we have analytics object
	AnalyticsObject = XComGameState_Analytics( History.GetSingleGameStateObjectForClass( class'XComGameState_Analytics', true ) );
	if (AnalyticsObject != none)
	{
		UnitState = XComGameState_Unit( EventData );
		PrevUnitState = XComGameState_Unit( History.GetPreviousGameStateForObject( UnitState ) );

		AnalyticsObject.AddUnitPromotion( UnitState, PrevUnitState );
	}

	return ELR_NoInterrupt;
}

defaultproperties
{
	bShouldSubmitGameState = true
	bAvaibleWorldStats = false
	bWaitingOnWorldStats = false
}