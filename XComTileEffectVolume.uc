/**
 * XComTileEffectActor
 * Author: David Burchanowski
 * Description:Volume used to indicate tiles that should be filled with world effects at tactical start.
 *              Note that startup logic is handled by XComTileEffectActor. Both do essentially the same thing,
 *              but since we already have a large amount of markup using the actor version of this functionality,
 *              it doesn't make sense to go back and change it. So they share what they can
 */
class XComTileEffectVolume extends Volume
	placeable
	native;

var() int Intensity;
var() class<X2Effect_World> TileEffect;
var() bool AutoApplyAtMissionStart;
var() float Coverage; // Percentage, 0.0-1.0, of the volume that should have the effect applied.

var editoronly transient ParticleSystemComponent PreviewParticleSystem;
var editoronly transient class<X2Effect_World> ActiveParticleTileEffect;

cpptext
{
	virtual void PostEditChangeProperty( struct FPropertyChangedEvent& PropertyChangedEvent );
	virtual UBOOL Tick( FLOAT DeltaTime, enum ELevelTick TickType );

	void StartParticlePreviewEffect( );
}


// returns a list of all tiles that lie inside this volume and should have the effect applied,
// as well as the intensity that should be applied at each tile
// If AllPossible is true, the Coverage parameter is ignored and every possible tile is returned.
// This is to support clearing the effect, since the random coverage is not deterministic
native function GetAffectedTiles(out array<TilePosPair> Tiles, out array<int> Intensities, optional bool AllPossible = true);

// Removes this effect from all tiles contained in the volume
native function ClearAffectedTiles(XComGameState NewGameState);

defaultproperties
{
	bMovable=true
	AutoApplyAtMissionStart=true
	Coverage=0.25
		
	Begin Object Class=SpriteComponent Name=Sprite
		Sprite=Texture2D'EditorResources.EffectActorSprite'
		Scale=0.25
		AlwaysLoadOnClient=FALSE
		AlwaysLoadOnServer=FALSE
		HiddenGame=true
	End Object
	Components.Add(Sprite)
	Layer=fX
}