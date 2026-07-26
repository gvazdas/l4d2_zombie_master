#if defined _zm_models_included
 #endinput
#endif
#define _zm_models_included

#define MODEL_SMOKER "models/infected/smoker.mdl"
#define MODEL_BOOMER "models/infected/boomer.mdl"
#define MODEL_HUNTER "models/infected/hunter.mdl"
#define MODEL_SPITTER "models/infected/spitter.mdl"
#define MODEL_JOCKEY "models/infected/jockey.mdl"
#define MODEL_CHARGER "models/infected/charger.mdl"
#define MODEL_TANK "models/infected/hulk.mdl"
#define MODEL_WITCH "models/infected/witch.mdl"

// Common Infected
#define MODEL_COMMON "models/infected/common_shadertest.mdl"
// common_morph_test common_test

#define MODEL_RIOT "models/infected/common_male_riot.mdl"
#define MODEL_RIOT2 "models/infected/common_male_riot_l4d1.mdl"

#define MODEL_CEDA "models/infected/common_male_ceda.mdl"
#define MODEL_CEDA2 "models/infected/common_male_ceda_l4d1.mdl"

#define MODEL_CLOWN "models/infected/common_male_clown.mdl"

#define MODEL_MUD "models/infected/common_male_mud.mdl"
#define MODEL_MUD2 "models/infected/common_male_mud_l4d1.mdl"

#define MODEL_ROAD "models/infected/common_male_roadcrew.mdl"
#define MODEL_ROAD2 "models/infected/common_male_roadcrew_rain.mdl"
#define MODEL_ROAD3 "models/infected/common_male_roadcrew_l4d1.mdl"
#define MODEL_ROAD4 "models/infected/common_male_baggagehandler_02.mdl"

#define MODEL_JIMMY "models/infected/common_male_jimmy.mdl"

#define MODEL_FALLEN "models/infected/common_male_fallen_survivor.mdl"
#define MODEL_FALLEN2 "models/infected/common_male_parachutist.mdl"
#define MODEL_FALLEN3 "models/infected/common_male_fallen_survivor_l4d1.mdl" // this one has 2 bodygroups as well

enum // ty Silvers
{
	TYPE_COMMON         = 1,
    TYPE_CEDA			= 11,
	TYPE_MUD_MEN		= 12,
	TYPE_ROAD_WORKER	= 13,
	TYPE_FALLEN		    = 14,
	TYPE_RIOT			= 15,
	TYPE_CLOWN		    = 16,
	TYPE_JIMMY_GIBBS	= 17
}

// set label for given uncommon gender
stock void gender_to_label(const int gender, char label[16])
{
    switch (gender)
    {
        case TYPE_CEDA: label = "ceda";
        case TYPE_MUD_MEN: label = "mud";
        case TYPE_ROAD_WORKER: label = "road";
        case TYPE_FALLEN: label = "fallen";
        case TYPE_RIOT: label = "riot";
        case TYPE_CLOWN: label = "clown";
        case TYPE_JIMMY_GIBBS: label = "jimmy";
        default: label = "";
    }
}

// Types to roll for "random" infected
int iRandomInfectedTypes[5] = {TYPE_RIOT,TYPE_CEDA,TYPE_MUD_MEN,TYPE_ROAD_WORKER,TYPE_CLOWN};

// Roll gender for given label.
stock int label_to_gender(const char arg[16])
{
    switch (arg[0])
    {
        case 'r':
        {
            if (strcmp(arg,"random")==0)
            {
                if (g_hCostRiot.IntValue>=0) return iRandomInfectedTypes[GetRandomInt(0,sizeof(iRandomInfectedTypes)-1)];
                return iRandomInfectedTypes[GetRandomInt(1,sizeof(iRandomInfectedTypes)-1)];
            }
            else if (strcmp(arg,"riot")==0 && g_hCostRiot.IntValue>=0) return TYPE_RIOT;
            else if (strcmp(arg,"road")==0) return TYPE_ROAD_WORKER;
        }
        case 'c':
        {
            if (strcmp(arg,"ceda")==0) return TYPE_CEDA;
            else if (strcmp(arg,"clown")==0) return TYPE_CLOWN;
        }
        case 'm':
        {
            return TYPE_MUD_MEN;
        }
        case 'j':
        {
            return TYPE_JIMMY_GIBBS;
        }
        case 'f':
        {
            return TYPE_FALLEN;
        }
    }
    return TYPE_COMMON;
}

// Get random infected models for given gender.
stock void infected_gender_to_model(const int gender = TYPE_COMMON, char model[PLATFORM_MAX_PATH])
{
    switch (gender)
    {
        case TYPE_CEDA:
        {
            switch (GetRandomInt(0,1))
            {
                case 1: model = MODEL_CEDA2;
                default: model = MODEL_CEDA;
            }
        }
        case TYPE_MUD_MEN:
        {
            switch (GetRandomInt(0,1))
            {
                case 1: model = MODEL_MUD2;
                default: model = MODEL_MUD;
            }
        }
        case TYPE_ROAD_WORKER:
        {
            switch (GetRandomInt(0,3))
            {
                case 1: model = MODEL_ROAD2;
                case 2: model = MODEL_ROAD3;
                case 3: model = MODEL_ROAD4;
                default: model = MODEL_ROAD;
            }
        }
        case TYPE_FALLEN:
        {
            switch (GetRandomInt(0,2))
            {
                case 1: model = MODEL_FALLEN2;
                case 2: model = MODEL_FALLEN3;
                default: model = MODEL_FALLEN;
            }
        }
        case TYPE_RIOT:
        {
            switch (GetRandomInt(0,1))
            {
                case 1: model = MODEL_RIOT2;
                default: model = MODEL_RIOT;
            }
        }
        case TYPE_CLOWN: model = MODEL_CLOWN;
        case TYPE_JIMMY_GIBBS: model = MODEL_JIMMY;
        default: model = "";
    }
}

stock bool valid_uncommon(const char arg[16])
{
    if (strcmp(arg,"",false)==0 || arg[0]==0 || arg[0]==' ') return false;
    switch (arg[0])
    {
        case 'r':
        {
            if (strcmp(arg,"random")==0) return true;
            else if (strcmp(arg,"riot")==0 && g_hCostRiot.IntValue>=0) return true;
            else if (strcmp(arg,"road")==0) return true;
        }
        case 'c':
        {
            if (strcmp(arg,"ceda")==0) return true;
            else if (strcmp(arg,"clown")==0) return true;
        }
        case 'm':
        {
            if (strcmp(arg,"mud")==0) return true;
        }
        case 'j':
        {
            if (strcmp(arg,"jimmy")==0) return true;
        }
        case 'f':
        {
            if (strcmp(arg,"fallen")==0) return true;
        }
    }
	return false;
}


stock void ResetZombieModels()
{
    for(int i = 0; i < sizeof(g_hZombieModels); i++)
    {
        delete g_hZombieModels[i];
        g_hZombieModels[i] = null;
    }
    g_bZombieModelsLoaded = false;
}

stock void AddZombieModel(const int zClass, char[] model)
{
    if (g_hZombieModels[zClass]==null) g_hZombieModels[zClass] = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH))
    if (DEBUG) LogMessage("AddZombieModel %d %s", zClass, model);
    g_hZombieModels[zClass].PushString(model);
}

// Get a random zombie model based on zm menu state and game rules.
stock void GetRandomZombieModel(const int zClass, char[] model, const int size = PLATFORM_MAX_PATH)
{
    if (zClass==ZOMBIECLASS_COMMON)
    {
        static int gender;
        if (valid_uncommon(g_sForceCommon))
        {
            gender = label_to_gender(g_sForceCommon);
            if (calculate_infected_cost(gender)>=0)
            {
                infected_gender_to_model(gender,model);
                if (model[0]!=0) return;
            }
        }
        if (zm_menu_state == ZM_MENU_UNCOMMON || g_iCostCommon<0)
        {
            gender = label_to_gender("random");
            if (calculate_infected_cost(gender)>=0)
            {
                infected_gender_to_model(gender,model);
                if (model[0]!=0) return;
            }
        }
        if (zm_menu_state == ZM_MENU_BOSS)
        {
            switch(GetRandomInt(0,1))
            {
                case 0: infected_gender_to_model(TYPE_JIMMY_GIBBS,model);
                default: infected_gender_to_model(TYPE_FALLEN,model);
            }
            if (model[0]!=0) return;
        }
    }
    ReadZombieModels();
    if (g_hZombieModels[zClass]!=null && g_hZombieModels[zClass].Length>0)
    {
        int i = 0;
        if (g_hZombieModels[zClass].Length>1) i = GetRandomInt(0,g_hZombieModels[zClass].Length-1);
        g_hZombieModels[zClass].GetString(i,model,size);
        if (model[0]!=0) return;
    }
    switch (zClass)
    {
        case ZOMBIECLASS_BOOMER: strcopy(model,size,MODEL_BOOMER);
        case ZOMBIECLASS_CHARGER: strcopy(model,size,MODEL_CHARGER);
        case ZOMBIECLASS_HUNTER: strcopy(model,size,MODEL_HUNTER);
        case ZOMBIECLASS_JOCKEY: strcopy(model,size,MODEL_JOCKEY);
        case ZOMBIECLASS_SMOKER: strcopy(model,size,MODEL_SMOKER);
        case ZOMBIECLASS_SPITTER: strcopy(model,size,MODEL_SPITTER);
        case ZOMBIECLASS_TANK: strcopy(model,size,MODEL_TANK);
        case ZOMBIECLASS_WITCH: strcopy(model,size,MODEL_WITCH);
        default: strcopy(model,size,MODEL_COMMON);
    }
}

// Find all precached common infected, special infected and witch models in modelprecache stringtable.
// Thanks SilverShot for figuring this out
stock void ReadZombieModels()
{
	if (g_bZombieModelsLoaded || g_hPreview.IntValue<=1) return;
    int table = FindStringTable("modelprecache");
	int total = GetStringTableNumStrings(table);
	static char sTemp[PLATFORM_MAX_PATH];
	for( int i = 0; i < total; i++ )
	{
		ReadStringTable(table, i, sTemp, sizeof(sTemp));
        if (strncmp(sTemp,"models/infected",15,false)!=0) continue;
        if (StrContains(sTemp,"_w_",false)>=0) continue;

		if (strncmp(sTemp,"models/infected/common",22,false)==0) AddZombieModel(ZOMBIECLASS_COMMON,sTemp);
        else if(strncmp(sTemp,"models/infected/smoker",22,false)==0)
        {
            if (StrContains(sTemp,"tongue",false)>=0) continue;
            AddZombieModel(ZOMBIECLASS_SMOKER,sTemp);
        }
        else if(strncmp(sTemp,"models/infected/boome",21,false)==0) AddZombieModel(ZOMBIECLASS_BOOMER,sTemp);
        else if(strncmp(sTemp,"models/infected/hunter",22,false)==0) AddZombieModel(ZOMBIECLASS_HUNTER,sTemp);
        else if(strncmp(sTemp,"models/infected/spitter",23,false)==0) AddZombieModel(ZOMBIECLASS_SPITTER,sTemp);
        else if(strncmp(sTemp,"models/infected/jockey",22,false)==0) AddZombieModel(ZOMBIECLASS_JOCKEY,sTemp);
        else if(strncmp(sTemp,"models/infected/charger",23,false)==0) AddZombieModel(ZOMBIECLASS_CHARGER,sTemp);
        else if(strncmp(sTemp,"models/infected/witch",21,false)==0) AddZombieModel(ZOMBIECLASS_WITCH,sTemp);
        else if(strncmp(sTemp,"models/infected/hulk",20,false)==0) AddZombieModel(ZOMBIECLASS_TANK,sTemp);
	}
    g_bZombieModelsLoaded = true;
}






// DEPRECATED
stock void get_uncommon_model(const char label[16], char model[PLATFORM_MAX_PATH])
{
    model = "";
    if (strcmp(label,"",false)==0 || label[0]==0 || label[0]==' ') return;
    switch (label[0])
    {
        case 'r':
        {
            if (strcmp(label,"random",false)==0)
            {
                switch (GetRandomInt( (g_hCostRiot.IntValue>=0) ? 1 : 2 , 5))
                {
                    case 1: get_uncommon_model("riot",model);
                    case 2: get_uncommon_model("road",model);
                    case 3: get_uncommon_model("ceda",model);
                    case 4: get_uncommon_model("clown",model);
                    case 5: get_uncommon_model("mud",model);
                }
                return;
            }
            else if (strcmp(label,"riot",false)==0)
            {
                switch (GetRandomInt(0,1))
                {
                    case 1: model = MODEL_RIOT2;
                    default: model = MODEL_RIOT;
                }
            }
            else if (strcmp(label,"road",false)==0)
            {
                switch (GetRandomInt(0,3))
                {
                    case 1: model = MODEL_ROAD2;
                    case 2: model = MODEL_ROAD3;
                    case 3: model = MODEL_ROAD4;
                    default: model = MODEL_ROAD;
                }
            }
        }
        case 'c':
        {
            if (strcmp(label,"ceda",false)==0)
            {
                switch (GetRandomInt(0,1))
                {
                    case 1: model = MODEL_CEDA2;
                    default: model = MODEL_CEDA;
                }
            }
            else if (strcmp(label,"clown",false)==0) model = MODEL_CLOWN;
        }
        case 'm':
        {
            if (strcmp(label,"mud",false)==0)
            {
                switch (GetRandomInt(0,1))
                {
                    case 1: model = MODEL_MUD2;
                    default: model = MODEL_MUD;
                }
            }
        }
        case 'j': model = MODEL_JIMMY;
        case 'f':
        {
            if (strcmp(label,"fallen",false)==0)
            {
                switch (GetRandomInt(0,2))
                {
                    case 1: model = MODEL_FALLEN2;
                    case 2: model = MODEL_FALLEN3;
                    default: model = MODEL_FALLEN;
                }
            }
        }
        default: model = ""; 
    }
}