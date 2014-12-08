#!/bin/bash

# Copyright (C) 2009-2014 Ed Bueler and Andy Aschwanden

set -e # exit on error
SCRIPTNAME=Variability.sh

CLIMLIST=(const, pdd)
TYPELIST=(ctrl, old_bed, 970mW_hs, jak_1985)
GRIDLIST=(18000 9000 4500 3600 1800 1500 1200 900 600 450)
if [ $# -lt 5 ] ; then
  echo "paramspawn.sh ERROR: needs 5 positional arguments ... ENDING NOW"
  echo
  echo "usage:"
  echo
  echo "    paramspawn.sh NN GRID CLIMATE TYPE REGRIDFILE"
  echo
  echo "  where:"
  echo "    PROCSS       = 1,2,3,... is number of MPI processes"
  echo "    GRID      in (${GRIDLIST[@]})"
  echo "    CLIMATE   in (${CLIMLIST[@]})"
  echo "    TYPE      in (${TYPELIST[@]})"
  echo "    REGRERIDFILE  name of regrid file"
  echo
  echo
  exit
fi

NN=64  # default number of processors
if [ $# -gt 0 ] ; then  # if user says "paramspawn.sh 8" then NN = 8
  NN="$1"
fi

# set wallclock time
if [ -n "${PISM_WALLTIME:+1}" ] ; then  # check if env var is already set
  echo "$SCRIPTNAME                    PISM_WALLTIME = $PISM_WALLTIME  (already set)"
else
  PISM_WALLTIME=12:00:00
  echo "$SCRIPTNAME                     PISM_WALLTIME = $PISM_WALLTIME"
fi
WALLTIME=$PISM_WALLTIME

if [ -n "${PISM_PROCS_PER_NODE:+1}" ] ; then  # check if env var is already set
    PISM_PROCS_PER_NODE=$PISM_PROCS_PER_NODE
else
    PISM_PROCS_PER_NODE=4
fi
PROCS_PER_NODE=$PISM_PROCS_PER_NODE

if [ -n "${PISM_QUEUE:+1}" ] ; then  # check if env var is already set
    PISM_QUEUE=$PISM_QUEUE
else
    PISM_QUEUE=standard_4
fi
QUEUE=$PISM_QUEUE

# set output format:
#  $ export PISM_OFORMAT="netcdf4_parallel "
if [ -n "${PISM_OFORMAT:+1}" ] ; then  # check if env var is already set
  echo "$SCRIPTNAME                      PISM_OFORMAT = $PISM_OFORMAT  (already set)"
else
  PISM_OFORMAT="netcdf3"
  echo "$SCRIPTNAME                      PISM_OFORMAT = $PISM_OFORMAT"
fi
OFORMAT=$PISM_OFORMAT

# set GRID from argument 2
if [ "$2" = "18000" ]; then
    GRID=$2
elif [ "$2" = "9000" ]; then
    GRID=$2
elif [ "$2" = "4500" ]; then
    GRID=$2
elif [ "$2" = "3600" ]; then
    GRID=$2
elif [ "$2" = "1800" ]; then
    GRID=$2
elif [ "$2" = "1500" ]; then
    GRID=$2
elif [ "$2" = "1200" ]; then
    GRID=$2
elif [ "$2" = "900" ]; then
    GRID=$2
elif [ "$2" = "600" ]; then
    GRID=$2
elif [ "$2" = "450" ]; then
    GRID=$2
else
  echo "invalid second argument; must be in (${GRIDLIST[@]})"
  exit
fi


# set CLIMATE from argument 3
if [ "$3" = "const" ]; then
    CLIMATE=$3
elif [ "$3" = "pdd" ]; then
    CLIMATE=$3
else
  echo "invalid third argument; must be in (${CLIMLIST[@]})"
  exit
fi

# set TYPE from argument 4
if [ "$4" = "ctrl" ]; then
    TYPE=$4
elif [ "$4" = "old_bed" ]; then
    TYPE=$4
elif [ "$4" = "970mW_hs" ]; then
    TYPE=$4
elif [ "$4" = "jak_1985" ]; then
    TYPE=$4
else
  echo "invalid forth argument; must be in (${TYPELIST[@]})"
  exit
fi

REGRIDFILE=$5
PISM_DATANAME=pism_Greenland_${GRID}m_mcb_jpl_v1.1_${TYPE}.nc
DURA=500000
NODES=$(( $NN/$PROCS_PER_NODE))

 SHEBANGLINE="#!/bin/bash"
MPIQUEUELINE="#PBS -q $QUEUE"
 MPITIMELINE="#PBS -l walltime=$WALLTIME"
 MPISIZELINE="#PBS -l nodes=$NODES:ppn=$PROCS_PER_NODE"
  MPIOUTLINE="#PBS -j oe"

# ########################################################
# set up parameter sensitivity study: null
# ########################################################


SAVE="25101,25446,25707,25840,26138,26257,26545,26672,27053,27350,27393,27628,27926,28215,28394,28614,28920,29157,29466,29543,29785,29989,30427,30628,30893,30964,31293,31628,31653,31918,32254,32488,32703,32969,33218,33507,33643,33973,34123,34271,34538,34931,35202,35243,35657,35790,36089,36237,36457,36847,37016,37176,37454,37796,37855,38297,38340,38541,38969,39106,39306,39631,39731,40068,40355,40449,40805,41007,41284,41402,41754,42056,42314,42541,42758,42898,43134,43509,43529,43814,44220,44327,44480,44852,45002,45204,45649,45685,46051,46238,46593,46668,47041,47279,47547,47674,47971,48201,48296,48743,48795,49082,49375,49472,49807,50092,50308,50431,50881,51088,51204,51368,51695,51936,52137,52496,52625,52797,53117,53477,53538,53951,54125,54405,54466,54711,55131,55232,55437,55712,56002,56157,56540,56782,56947,57079,57306,57579,57826,58168,58252,58684,58956,59023,59202,59499,59792,59987,60362,60557,60824,60884,61132,61527,61641,61967,62218,62345,62551,62792,63190,63316,63697,63947,64166,64294,64460,64687,65105,65187,65450,65808,65918,66220,66444,66775,66997,67055,67320,67663,67811,68144,68241,68698,68825,68975,69252,69612,69686,70051,70247,70491,70770,70990,71171,71463,71673,71857,72142,72486,72658,72741,73122,73214,73681,73838,74032,74198,74605,74805,74922,75318,75421,75663,76033,76082,76305,76713,76781,77161,77330,77667,77787,78019,78253,78526,78884,79104,79373,79621,79832,79915,80254,80426,80662,80968,81213,81350,81656,81884,82219,82316,82510,82881,82982,83416,83507,83718,83995,84323,84483,84701,85002,85295,85448,85701,85919,86076,86457,86624,86876,87065,87255,87539,87720,88064,88325,88482,88695,88989,89143,89468,89714,89904,90215,90528,90604,90865,91207,91305,91500,91936,92108,92232,92552,92713,92928,93351,93418,93858,93986,94170,94549,94794,94889,95113,95444,95572,95920,96201,96369,96596,96817,97140,97205,97442,97753,98147,98340,98586,98841,98956,99150,99519,99585,100015,100094,100463,100538,100973,101095,101346,101548,101924,102036,102226,102558,102736,102972,103370,103421,103683,104062,104109,104438,104614,104962,105143,105332,105551,105924,106047,106273,106658,106715,107145,107375,107454,107796,107941,108136,108469,108804,108924,109258,109545,109721,109914,110067,110492,110572,110812,111200,111291,111538,111744,112003,112167,112420,112735,113091,113160,113450,113792,113839,114174,114469,114545,114942,115162,115327,115693,115773,116197,116383,116589,116753,117134,117247,117424,117748,117927,118246,118440,118651,118979,119222,119379,119532,119818,120232,120353,120652,120770,121096,121206,121492,121666,122091,122319,122486,122685,122963,123159,123444,123632,123971,124105,124386,124544,124885,125080,125427,125523,125893,126019,126303,126454,126751,126966,127221,127520,127769,128014,128180,128505,128585,128888,129110,129485,129561,129910,130115,130378,130616,130917,130981,131168,131529,131638,131891,132244,132371,132745,132853,133166,133436,133674,133796,134114,134267,134598,134938,135150,135228,135466,135742,135952,136189,136554,136709,137093,137265,137379,137653,137825,138196,138289,138700,138824,139109,139333,139624,139867,140078,140284,140446,140731,140926,141167,141475,141641,141958,142147,142456,142773,142880,143189,143337,143587,143775,144134,144257,144479,144932,145006,145284,145592,145839,145974,146282,146477,146618,147010,147159,147485,147681,147790,148073,148459,148732,148791,149118,149374,149589,149897,149934,150358,150493,150714,150958,151148,151542,151809,151842,152102,152407,152591,152797,153067,153405,153534,153928,154179,154259,154438,154761,155041,155320,155444,155728,156051,156134,156337,156789,156923,157086,157395,157607,157983,158042,158284,158526,158742,159116,159315,159477,159704,160060,160254,160377,160622,161049,161236,161338,161684,161928,162214,162500,162739,162966,162995,163236,163588,163903,164072,164250,164637,164676,165083,165174,165564,165634,166042,166116,166326,166773,166808,167052,167433,167622,167835,168183,168337,168542,168847,168958,169323,169552,169800,169886,170269,170517,170634,171060,171111,171491,171545,171870,172176,172444,172621,172809,173087,173371,173571,173748,173968,174350,174592,174696,174900,175241,175378,175677,175914,176275,176331,176534,176859,177150,177258,177582,177850,178093,178354,178575,178786,178947,179251,179562,179777,179942,180321,180420,180668,180855,181075,181353,181598,181966,182204,182315,182638,182770,183151,183405,183450,183831,183979,184295,184584,184634,184964,185286,185392,185694,185881,186227,186263,186712,186955,187082,187252,187521,187729,187981,188190,188410,188870,188885,189246,189584,189760,189924,190182,190398,190752,190862,191147,191480,191553,191957,191969,192324,192659,192774,192997,193338,193549,193832,193925,194227,194516,194811,195037,195255,195494,195716,195937,196048,196249,196623,196915,196985,197277,197469,197790,197909,198177,198593,198656,198942,199266,199387,199663,199936,200172,200390,200601,200922,201008,201440,201654,201782,201979,202234,202626,202712,202993,203349,203591,203613,203949,204161,204424,204773,204974,205172,205427,205650,205810,206165,206229,206501,206844,207094,207171,207403,207703,208101,208161,208389,208613,208980,209202,209430,209689,209992,210157,210300,210567,210939,211077,211273,211455,211694,212009,212157,212542,212732,212871,213250,213348,213775,214006,214058,214441,214674,214938,215100,215403,215637,215845,216122,216228,216434,216870,217026,217198,217580,217822,217861,218230,218550,218616,218868,219056,219358,219632,219822,220224,220285,220697,220726,220984,221405,221645,221824,221979,222244,222468,222644,222983,223082,223400,223563,223792,224223,224293,224592,224745,225001,225228,225677,225689,226077,226255,226466,226727,227069,227142,227570,227664,227855,228161,228476,228715,228899,229038,229444,229718,229735,230103,230218,230519,230783,231100,231199,231458,231640,231869,232233,232385,232652,232953,233076,233465,233686,233975,234036,234473,234618,234715,235059,235197,235499,235840,236086,236224,236437,236788,236876,237218,237344,237745,237803,238130,238430,238747,238985,239076,239422,239631,239710,240035,240403,240614,240728,240968,241354,241365,241825,242007,242148,242494,242780,242967,243104,243390,243651,243895,244205,244213,244554,244744,244967,245220,245544,245801,245946,246167,246455,246642,247000,247217,247381,247675,247983,248235,248318,248707,248834,249002,249387,249612,249787,249986,250348,250531,250650,250964,251277,251473,251769,251862,252244,252382,252576,252770,253194,253352,253518,253819,254005,254416,254566,254696,255030,255334,255541,255802,255905,256139,256524,256712,256983,257185,257461,257740,257828,258087,258418,258626,258815,259026,259373,259532,259669,260024,260261,260413,260613,261026,261292,261500,261753,261944,262133,262490,262724,262803,263097,263359,263586,263855,263945,264289,264602,264749,265111,265270,265373,265626,265944,266294,266498,266620,266967,267249,267302,267542,267850,268145,268228,268480,268904,269003,269155,269527,269803,270021,270228,270534,270792,270972,271163,271524,271709,271927,272096,272372,272645,272919,273025,273303,273559,273855,274086,274277,274599,274814,274913,275248,275379,275642,275930,276140,276481,276685,276897,277139,277379,277477,277813,278060,278370,278417,278748,278975,279156,279551,279636,280056,280091,280524,280719,280811,281179,281453,281585,281949,282119,282216,282508,282897,283026,283397,283405,283761,283958,284129,284484,284702,284895,285113,285480,285774,285848,286121,286420,286602,286860,287102,287362,287495,287911,288113,288336,288407,288753,289080,289108,289391,289588,289831,290144,290309,290733,290762,291048,291249,291703,291805,292091,292349,292552,292776,292998,293273,293398,293736,294003,294159,294399,294660,294994,295135,295431,295709,295908,296059,296283,296482,296812,296988,297337,297550,297848,298067,298126,298372,298760,298963,299252,299461,299565,299862,300127,300278,300698,300945,301195,301264,301498,301786,301975,302193,302451,302873,302932,303125,303503,303722,303863,304261,304402,304738,304903,305060,305444,305717,305897,306165,306331,306506,306787,306970,307242,307598,307676,307902,308180,308436,308763,308842,309251,309368,309757,309850,310033,310444,310591,310775,311126,311204,311521,311820,311987,312221,312391,312801,313025,313122,313535,313601,314013,314192,314506,314740,314875,315022,315238,315480,315934,315949,316286,316546,316758,317101,317163,317462,317606,317869,318294,318448,318729,318892,319069,319428,319605,319860,320163,320292,320575,320745,320999,321257,321596,321728,322069,322197,322532,322689,322994,323143,323536,323555,323935,324173,324465,324594,324884,325169,325332,325578,325811,326123,326357,326493,326647,327041,327331,327553,327780,327989,328147,328374,328691,328862,329083,329293,329704,329903,329953,330293,330522,330727,331115,331270,331573,331750,331918,332135,332523,332768,332932,333038,333383,333542,333942,333997,334399,334553,334873,335110,335340,335443,335735,336000,336348,336523,336654,336933,337248,337501,337595,338013,338168,338285,338526,338923,339086,339281,339485,339722,340131,340163,340409,340696,340951,341320,341533,341777,341939,342163,342342,342764,342906,343038,343304,343582,343869,343974,344269,344476,344783,345051,345285,345603,345822,345980,346142,346452,346602,346922,347223,347493,347607,347909,348170,348366,348481,348792,349007,349404,349571,349850,350019,350353,350589,350643,350894,351294,351461,351632,351970,352265,352478,352614,352779,353004,353250,353601,353857,354077,354241,354520,354650,355097,355301,355593,355678,356053,356243,356325,356629,357020,357025,357417,357662,357814,358182,358405,358621,358793,359017,359251,359578,359682,359893,360295,360417,360688,360850,361152,361323,361542,361987,362066,362305,362629,362764,363177,363222,363531,363876,364047,364256,364549,364810,364997,365230,365380,365784,365974,366212,366383,366610,366967,367177,367292,367702,367920,368065,368298,368438,368851,369039,369307,369556,369730,369910,370298,370388,370654,370923,371160,371503,371651,371951,372003,372349,372595,372702,373004,373191,373637,373693,374111,374167,374567,374827,374841,375124,375317,375736,375944,376093,376454,376661,376909,377202,377268,377522,377828,378001,378332,378429,378750,379093,379295,379389,379823,379893,380164,380362,380740,380956,381201,381477,381721,381923,381971,382220,382608,382683,382969,383150,383461,383743,384058,384183,384426,384785,384891,385108,385293,385671,385902,386186,386313,386704,386753,387007,387374,387537,387752,388074,388143,388541,388737,389013,389163,389362,389630,389992,390271,390454,390566,390855,390987,391337,391481,391877,392034,392262,392622,392797,393020,393357,393384,393651,393844,394192,394544,394650,394864,395028,395421,395518,395922,396119,396232,396612,396800,396993,397185,397417,397850,397882,398314,398470,398728,398957,399286,399350,399553,399798,400177,400305,400542,400953,401074,401274,401654,401683,402117,402319,402623,402764,403060,403280,403529,403675,404026,404118,404458,404600,404794,405069,405263,405647,405791,406116,406348,406601,406786,406906,407207,407461,407734,407910,408309,408374,408728,409002,409168,409490,409664,409755,410218,410316,410555,410756,411046,411386,411607,411750,412055,412203,412434,412658,412847,413272,413425,413605,413805,414116,414465,414558,414771,415203,415317,415654,415773,415996,416295,416417,416860,417024,417280,417382,417813,418062,418231,418456,418733,418936,419244,419478,419542,419783,420157,420312,420444,420773,421068,421358,421591,421768,421937,422222,422545,422608,422949,423264,423413,423573,423828,424109,424268,424578,424718,425079,425407,425447,425741,425968,426169,426422,426627,427054,427100,427508,427729,427972,428224,428336,428523,428829,429150,429461,429464,429746,430005,430322,430544,430709,430963,431283,431569,431747,431919,432198,432544,432719,432816,433218,433343,433649,433815,434146,434321,434466,434894,435123,435244,435440,435653,436014,436339,436403,436665,436868,437082,437528,437704,437950,438040,438448,438703,438885,439011,439406,439454,439860,439930,440257,440467,440740,441080,441237,441482,441741,442017,442061,442354,442730,442872,443030,443325,443493,443776,444134,444249,444469,444840,445061,445287,445469,445810,445863,446110,446358,446733,446949,447199,447373,447693,447810,448190,448291,448523,448781,449070,449334,449480,449813,450017,450291,450367,450706,450976,451166,451482,451599,451955,452209,452313,452668,452774,453181,453346,453464,453899,453925,454336,454619,454737,454961,455296,455579,455776,455929,456070,456481,456604,456853,457175,457353,457639,457864,458151,458273,458458,458835,459053,459303,459613,459757,459981,460335,460498,460783,460868,461202,461328,461546,461875,462185,462465,462670,462765,463015,463200,463430,463708,463962,464294,464424,464792,465034,465200,465499,465607,465916,466236,466359,466552,466796,467179,467413,467519,467802,468049,468409,468414,468685,469093,469297,469378,469703,469902,470092,470468,470731,470873,471204,471311,471513,471785,472059,472246,472487,472867,473057,473337,473538,473839,474010,474119,474367,474757,474998,475096,475327,475752,475912,476152,476455,476590,476929,477100,477224,477520,477701,477978,478245,478497,478685,479071,479268,479520,479581,479882,480172,480519,480718,480886,481089,481245,481622,481741,482113,482206,482593,482764,483014,483203,483471,483831,483952,484139,484391,484599,484913,485177,485422,485580,485807,486207,486362,486653,486910,486946,487412,487548,487733,488071,488259,488575,488659,489028,489118,489329,489658,489927,490065,490480,490618,490770,490998,491310,491453,491913,492038,492340,492608,492735,493089,493316,493531,493600,493855,494063,494481,494570,494948,495218,495435,495660,495820,496072,496328,496501,496682,496991,497217,497585,497663,497907,498156,498466,498713,499027,499168,499329,499666,499782 -save_split"
EXPERIMENT=${CLIMATE}_${TYPE}_sia
SCRIPT=do_g${GRID}m_${EXPERIMENT}.sh
rm -f $SCRIPT

# insert preamble
echo $SHEBANGLINE >> $SCRIPT
echo >> $SCRIPT # add newline
echo $MPIQUEUELINE >> $SCRIPT
echo $MPITIMELINE >> $SCRIPT
echo $MPISIZELINE >> $SCRIPT
echo $MPIOUTLINE >> $SCRIPT
echo >> $SCRIPT # add newline
echo "cd \$PBS_O_WORKDIR" >> $SCRIPT
echo >> $SCRIPT # add newline

export PISM_EXPERIMENT=$EXPERIMENT
export PISM_TITLE="Greenland Internal Variability Study"
INFILE=$PISM_DATANAME
OUTFILE=g${GRID}m_${EXPERIMENT}_${DURA}ka.nc
                
cmd="PISM_DO="" PISM_OFORMAT=$OFORMAT PISM_DATANAME=$PISM_DATANAME TSSTEP=yearly EXSTEP=10 PISM_SAVE=$SAVE EXSPLIT=foo ./run.sh $NN $CLIMATE $DURA $GRID sia null $OUTFILE $INFILE"
echo "$cmd 2>&1 | tee job.\${PBS_JOBID}" >> $SCRIPT                            
echo >> $SCRIPT

echo "# $SCRIPT written"
echo




