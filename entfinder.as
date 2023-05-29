/* entfinder
    Script to find stuff w/ commands

    Commands:-
    "find_edict": prints info for an entity at a given entindex
    "find_entity_center": prints entity center point value
    "find_radius": prints info for entities found within a given radius
    "find_pvs": prints info for entities found within the given entity's pvs
    "find_missing_brushmodels": prints all orphaned brush models unused by entities in the bsp, using 1 as an argument spawns them

    This script is WIP and more features will be added if the need for them arises
    - Outerbeast
*/
namespace ENTFINDER
{

const string strDebugMsgPrefix = " !------ENTFINDER------!  ";
const array<CClientCommand@> CMD_FIND =
{
    CClientCommand( "find_missing_brushmodels", "Finds missing brush models", FindMissingBrushModels ),
    CClientCommand( "find_entity_center", "Gives entity center point", FindEntityCenter ),
    CClientCommand( "find_edict", "Finds an entity at edict number", FindEdict ),
    CClientCommand( "find_radius", "Finds entities in PVS", FindRadius ),
    CClientCommand( "find_pvs", "Finds entities in PVS", FindPVS )
};

array<string> STR_BRUSHMODELS;
CScheduledFunction@ fnGetCurrentBrushEnts = g_Scheduler.SetTimeout( "GetCurrentBrushEnts", 0.0f );

void PrintEntInfo(CBaseEntity@ pEntity)
{
    if( pEntity is null )
        return;

    string strInfo = pEntity.GetClassname();
    strInfo += pEntity.GetTargetname() != "" ? "\nTargetname: " + pEntity.GetTargetname() : "";
    strInfo += "\nPosition: " + pEntity.pev.origin.ToString().Replace( ",", "" );
    strInfo += "\nAngles: " + pEntity.pev.angles.ToString().Replace( ",", "" );
    strInfo += pEntity.pev.model != "" ? "\nModel: " + pEntity.pev.model : "";

    g_EngineFuncs.ServerPrint( strDebugMsgPrefix + strInfo + "\n" );
}

void GetCurrentBrushEnts()
{
    STR_BRUSHMODELS.resize( 0 );

    const Vector
		vecWorldMins = Vector( -WORLD_BOUNDARY, -WORLD_BOUNDARY, -WORLD_BOUNDARY ),
		vecWorldMaxs = Vector( WORLD_BOUNDARY, WORLD_BOUNDARY, WORLD_BOUNDARY );

	array<CBaseEntity@> P_ENTITIES( g_EngineFuncs.NumberOfEntities() );

	if( g_EntityFuncs.BrushEntsInBox( @P_ENTITIES, vecWorldMins, vecWorldMaxs ) < 1 )
		return;

	for( uint i = 0; i < P_ENTITIES.length(); i++ )
	{
        if( P_ENTITIES[i] is null || !P_ENTITIES[i].IsBSPModel() )
            continue;

        if( STR_BRUSHMODELS.find( string( P_ENTITIES[i].pev.model ) ) >= 0 )
            continue;

        uint iCurrentBrushMdl = atoi( string( P_ENTITIES[i].pev.model ).Replace( "*", "" ) );
        STR_BRUSHMODELS.resize( iCurrentBrushMdl + 1 );
        STR_BRUSHMODELS[iCurrentBrushMdl] = "" + P_ENTITIES[i].pev.model;
        //g_EngineFuncs.ServerPrint( strDebugMsgPrefix + "Found existing brush model: " + P_ENTITIES[i].pev.model + "\n" );
    }
}

bool BrushExists(const string strModel)
{
    CBaseEntity@ pExistingBrush;

    while( ( @pExistingBrush = g_EntityFuncs.FindEntityByString( pExistingBrush, "model", strModel ) ) !is null )
    {
        if( @pExistingBrush is null || !pExistingBrush.IsBSPModel() || pExistingBrush.GetTargetname().StartsWith( "missing_brush_#" ) )
            continue;

        return pExistingBrush !is null;
    }

    return false;
}

void FindMissingBrushModels(const CCommand@ cmdArgs)
{
    if( cmdArgs.ArgC() < 1 || cmdArgs[0][0] != "find_missing_brushmodels" )
        return;

    string strInfo;

    for( uint i = 1; i < STR_BRUSHMODELS.length(); i++ )
    {
        if( STR_BRUSHMODELS[i] == "" )
        {
            CBaseEntity@ pMissingBrush = g_EntityFuncs.CreateEntity( "func_wall_toggle", {{ "model", "*" + i }, { "targetname", "missing_brush_#" + i }}, false );

            if( !BrushExists( string( pMissingBrush.pev.model ) ) )
            {
                strInfo = strDebugMsgPrefix + "Found missing brush model: " + pMissingBrush.pev.model;

                if( atoi( cmdArgs[1] ) > 0 )
                {
                    g_EntityFuncs.DispatchSpawn( pMissingBrush.edict() );
                    strInfo += " spawned at position: " + pMissingBrush.Center().ToString().Replace( ",", "" );
                }

                g_EngineFuncs.ServerPrint( strInfo + "\n" );
            }
            else
                g_EntityFuncs.Remove( pMissingBrush );
        }
    }

    if( strInfo == "" )
        g_EngineFuncs.ServerPrint( strDebugMsgPrefix + "No missing brush entities found." );
}

void FindEntityCenter(const CCommand@ cmdArgs)
{
    if( cmdArgs.ArgC() < 1 || cmdArgs[0][0] != "find_entity_center" )
        return;

    CBaseEntity@ pEntity;

    if( cmdArgs[1] != "" )
    {
        while( ( @pEntity = g_EntityFuncs.FindEntityByTargetname( pEntity, cmdArgs[1] ) ) !is null )
        {
            if( pEntity is null )
            {
                g_EngineFuncs.ServerPrint( strDebugMsgPrefix + "No entity with that name found.\n" );
                continue;
            }

            g_EngineFuncs.ServerPrint( strDebugMsgPrefix + pEntity.GetClassname() + " center point: " + pEntity.Center().ToString().Replace( ",", "" ) + "\n" );
        }
    }
    else
    {
        @pEntity = g_Utility.FindEntityForward( g_ConCommandSystem.GetCurrentPlayer() );

        if( pEntity is null || !pEntity.IsBSPModel() )
        {
            g_EngineFuncs.ServerPrint( strDebugMsgPrefix + "No entity ahead.\n" );
            return;
        }
        else
            g_EngineFuncs.ServerPrint( strDebugMsgPrefix + pEntity.GetClassname() + " center point: " + pEntity.Center().ToString().Replace( ",", "" ) + "\n" );
    }
}

void FindEdict(const CCommand@ cmdArgs)
{
    if( cmdArgs.ArgC() < 1 || cmdArgs[0][0] != "find_edict" )
        return;

    if( cmdArgs[1] == "" || atoi( cmdArgs[1] ) < 0 )
    {
        g_EngineFuncs.ServerPrint( strDebugMsgPrefix + "Please enter a valid entity index number to search.\n" );
        return;
    }

    CBaseEntity@ pEntity = g_EntityFuncs.Instance( atoi( cmdArgs[1] ) );

    if( pEntity is null )
    {
        g_EngineFuncs.ServerPrint( strDebugMsgPrefix + " Entity at edict " + cmdArgs[1] + " not found.\n" );
        return;
    }

    PrintEntInfo( pEntity );
}

void FindRadius(const CCommand@ cmdArgs)
{
    if( cmdArgs.ArgC() < 1 || cmdArgs[0][0] != "find_radius" )
        return;

    const Vector vecOrigin = g_ConCommandSystem.GetCurrentPlayer().pev.origin;
    const float flRadius = atof( cmdArgs[1] );

    if( flRadius <= 0 )
    {
        g_EngineFuncs.ServerPrint( strDebugMsgPrefix + "Please enter a valid radius to search.\n" );
        return;
    }

    CBaseEntity@ pEntity;

    while( ( @pEntity = g_EntityFuncs.FindEntityInSphere( pEntity, vecOrigin, flRadius, "*", "classname" ) ) !is null )
    {
        if( pEntity is null || pEntity is g_ConCommandSystem.GetCurrentPlayer() )
            continue;

        PrintEntInfo( pEntity );
    }
}

void FindPVS(const CCommand@ cmdArgs)
{
    if( cmdArgs.ArgC() < 1 || cmdArgs[0][0] != "find_pvs" )
        return;

    edict_t@ eStartEntity, ePVSEntity;

    if( cmdArgs[1] != "" && g_EntityFuncs.FindEntityByTargetname( null, cmdArgs[1] ) !is null )
        @eStartEntity = g_EntityFuncs.FindEntityByTargetname( null, cmdArgs[1] ).edict();
    else
        @eStartEntity = g_ConCommandSystem.GetCurrentPlayer().edict();

    if( eStartEntity is null )
        return;

    @ePVSEntity = g_EngineFuncs.EntitiesInPVS( eStartEntity );

    if( ePVSEntity is null )
    {
        g_EngineFuncs.ServerPrint( strDebugMsgPrefix + " No entities in PVS found.\n" );
        return;
    }

    do
    {
        if( ePVSEntity is eStartEntity || ePVSEntity.vars.size == g_vecZero ) // Physical entities only
        {
            @ePVSEntity = ePVSEntity.vars.chain;
            continue;
        }

        PrintEntInfo( g_EntityFuncs.Instance( ePVSEntity ) );
        @ePVSEntity = ePVSEntity.vars.chain;
    }
    while( ePVSEntity !is null );
}

}
