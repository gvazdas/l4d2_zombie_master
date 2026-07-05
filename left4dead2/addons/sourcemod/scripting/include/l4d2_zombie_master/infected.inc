#if defined _zm_infected_included
 #endinput
#endif
#define _zm_infected_included

// infected entity logistics

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

// Calculate cost to spawn infected entity. -1 if spawning is illegal.
stock int calculate_infected_cost(const int gender = 1, const bool angry = false)
{
    int cost = 0;
    if (gender==TYPE_RIOT) cost = g_hCostRiot.IntValue;
    else if (gender>=TYPE_CEDA) cost = g_iCostUncommon;
    else cost = g_iCostCommon;

    if (cost<0) return -1;

    if (angry)
    {
        if (g_hCostAngry.IntValue<0) return -1;
        cost += g_hCostAngry.IntValue;
    }

    return cost;
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