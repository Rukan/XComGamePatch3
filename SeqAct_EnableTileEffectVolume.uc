//---------------------------------------------------------------------------------------
//  FILE:    SeqAct_EnableTileEffectVolume.uc
//  AUTHOR:  David Burchanowski
//  PURPOSE: Fades the camera out in a game state safe way
//           
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------

class SeqAct_EnableTileEffectVolume extends SequenceAction
	implements(X2KismetSeqOpVisualizer);

var() name VolumeTag;

event Activated()
{
}

function BuildVisualization(XComGameState GameState, out array<VisualizationTrack> VisualizationTracks)
{
	local X2Effect_World WorldEffect;
	local XComGameState_WorldEffectTileData WorldEffectData;
	local VisualizationTrack BuildTrack;

	foreach GameState.IterateByClassType(class'XComGameState_WorldEffectTileData', WorldEffectData)
	{
		BuildTrack.StateObject_OldState = WorldEffectData;
		BuildTrack.StateObject_NewState = WorldEffectData;
		WorldEffect = X2Effect_World(class'XComEngine'.static.GetClassDefaultObjectByName(WorldEffectData.WorldEffectClassName));
		WorldEffect.AddX2ActionsForVisualization(GameState, BuildTrack, '');
		VisualizationTracks.AddItem(BuildTrack);
		break;
	}
}

function ModifyKismetGameState(out XComGameState GameState)
{
	local XComTileEffectVolume EffectVolume;
	local array<TilePosPair> AffectedTiles;
	local array<int> AffectedIntensities;
	local X2Effect_World WorldEffect;

	// find all volumes with the given tag, and add (or remove) the effect from their tiles 
	foreach class'WorldInfo'.static.GetWorldInfo().AllActors(class'XComTileEffectVolume', EffectVolume)
	{
		if(EffectVolume.Tag == VolumeTag)
		{
			if(InputLinks[0].bHasImpulse)
			{
				EffectVolume.GetAffectedTiles(AffectedTiles, AffectedIntensities);
				WorldEffect = X2Effect_World(class'XComEngine'.static.GetClassDefaultObject(EffectVolume.TileEffect));
				WorldEffect.AddLDEffectToTiles(WorldEffect.GetWorldEffectClassName(), GameState, AffectedTiles, AffectedIntensities);
			}
			else
			{
				EffectVolume.ClearAffectedTiles(GameState);
			}
		}
	}
}

defaultproperties
{
	ObjCategory="Level"
	ObjName="Activate Tile Effect Volume"
	bCallHandler = false

	bConvertedForReplaySystem=true
	bCanBeUsedForGameplaySequence=true

	InputLinks(0)=(LinkDesc="Enable")
	InputLinks(1)=(LinkDesc="Disable")

	VariableLinks.Empty
	VariableLinks(0)=(ExpectedType=class'SeqVar_Name',LinkDesc="Volume Tag",PropertyName=VolumeTag)
}