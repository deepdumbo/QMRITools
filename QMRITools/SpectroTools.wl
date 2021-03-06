(* ::Package:: *)

(* ::Title:: *)
(*QMRITools SpectroTools*)


(* ::Subtitle:: *)
(*Written by: Martijn Froeling, PhD*)
(*m.froeling@gmail.com*)


(* ::Section:: *)
(*Begin Package*)


BeginPackage["QMRITools`SpectroTools`", Join[{"Developer`"}, Complement[QMRITools`$Contexts, {"QMRITools`SpectroTools`"}]]];


(* ::Section:: *)
(*Usage Notes*)


(* ::Subsection:: *)
(*Functions*)


ReadjMRUI::usage = 
"ReadJMRUI[file] read a jMRUI spectrum file. 
Output is the {time, spec, {begintime, samplingInterval}}."

ReadListData::usage = 
"ReadListData[file] reads a list/data raw data file from the philips MR platform. The input file can either be .list or .data file.
Ouput is {{rawData, noise}, {head, types}}."


MeanType::usage = 
"MeanType[kspace, types, type] calcualtes the Mean of the kspace data on type, where type is part of types. The kspace and types are generated by ReadListData.
MeanType[{kspace, types}, type] calcualtes the Mean of the kspace data on type, where type is part of types.
MeanType[kspace, types, {type,..}] calcualtes the Mean of the kspace data on each of the list type, where type is part of types.
Output is {kspace, types}."

TotalType::usage = 
"TotalType[kspace, types, type] calcualtes the Total of the kspace data on type, where type is part of types. The kspace and types are generated by ReadListData.
TotalType[{kspace, types}, type] calcualtes the Total of the kspace data on type, where type is part of types.
TotalType[kspace, types, {type,..}] calcualtes the Total of the kspace data on each of the list type, where type is part of types.
Output is {kspace, types}."

OrderKspace::usage = 
"OrderKspace[kspace, types, order] reorders the kspace data to order, where order is a list and each value is a part of types. The kspace and types are generated by ReadListData."

SagitalTranspose::usage = 
"SagitalTranspose[data] makes a transpose of the data of the second level ande reverses the slices."


FourierShift::usage = 
"FourierShift[data] shift the data to the right by half the data dimensions."

InverseFourierShift::usage = 
"InvserseFourierShift[data] shift the data to the left by half the data dimensions."

ShiftedFourier::usage = 
"ShiftedFourier[kpace] performs a FourierTransform on the kspace and then shifts the data half the data dimensions."

ShiftedInverseFourier::usage = 
"ShiftedInverseFourier[data] shifts the data half the data dimensions and then performs a InverseFourierTransform on the data."

FourierShifted::usage = 
"FourierShifted[kspace] shifts the kspace half the kspace dimensions and then performs a FourierTransform on the kspace."

InverseFourierShifted::usage = 
"InverseFourierShifted[data] performs a InverseFourierTransform on the data and then shifts the kspace half the kspace dimensions."

FourierKspace2D::usage = 
"FourierKspace2D[kspace,head] performs a 2D reconstruction of 2D kspace data. Where kspace and head are generated by ReadListData."

FourierKspaceCSI::usage = 
"FourierKspaceCSI[kspace,head] performs a 3D reconstruction of 3D CSI kspace data. Where kspace and head are generated by ReadListData."


(* ::Subsection:: *)
(*Options*)


(* ::Subsection:: *)
(*Error Messages*)


(* ::Section:: *)
(*Functions*)


Begin["`Private`"] 


(* ::Subsection:: *)
(*Import data*)


(* ::Subsubsection::Closed:: *)
(*ReadJMRUI file*)


SyntaxInformation[ReadjMRUI]={"ArgumentsPattern"->{_}}

ReadjMRUI[file_]:=Block[{imp,data,head,series,pts,spec,time},
imp=Import[file,"Data"];
data=Select[imp,AllTrue[#,NumericQ]&&#=!={}&];
head=Flatten[Select[imp,!AllTrue[#,NumericQ]&&#=!={}&]];
head=(StringTrim/@StringSplit[#<>" ",":"])&/@Select[head,StringContainsQ[#,":"]&];
head[[2;;,2]]=(ToExpression[StringReplace[#,"E"->" 10^" ]]&/@head[[2;;,2]])/.Null->0;
head=Thread[head[[All,1]]->head[[All,2]]];
series="DatasetsInFile"/.head;
pts="PointsInDataset"/.head;
data=Partition[data,pts];
spec=Reverse/@(data[[All,All,3]]+data[[All,All,4]]I);
time=(data[[All,All,1]]+data[[All,All,2]]I);
{time,spec,N@{"BeginTime","SamplingInterval"}/1000/.head}
]


(* ::Subsubsection::Closed:: *)
(*Read List Data*)


SyntaxInformation[ReadListData]={"ArgumentsPattern"->{_}}

ReadListData[file_]:=Block[{
fl,head,list,data,lab,dataIndex,dataVals,dataValsN,ruleKx,ruleKy,ruleKz,ruleCoil,
typ,pos,dataSplit,indexSplit, echo,
sizeInd,size,ind,off,noise,indData,nSamp,kspace,line,types,outData,outHead},

fl=StringReplace[file,{".list"->"",".data"->""}];
If[!FileExistsQ[fl<>".list"]||!FileExistsQ[fl<>".data"],Print["files not found"]];

(*read the data - longest part*)
list=ReadList[fl<>".list",String];
data=BinaryReadList[fl<>".data","Complex64"];

(*Get the header*)
head=StringSplit/@Select[list,StringTake[#,1]==="."&];
head = (p = Position[#, ":"][[1, 1]]; 
     StringRiffle[#[[5 ;; (p - 1)]]] -> 
      ToExpression[#[[(p + 1) ;;]]]) & /@ head;
head[[All,2]]=If[Length[#]==1,#[[1]],#]&/@head[[All,2]];
(*get the labels*)
lab=StringSplit[list[[StringPosition[StringJoin[StringTake[#,1]&/@list],"# "][[1,1]]-2]]][[2;;-2]];

(*parse text table*)
dataIndex=Transpose[StringSplitExp[Select[list,StringTake[#,1]===" "&]]];(*longest part*)

(*create header values*)
dataVals=Thread[lab->(Sort[DeleteDuplicates[#]]&/@dataIndex)];
dataValsN=Thread["N_"<>#&/@dataVals[[All,1]]->Length/@dataVals[[All,2]] ];
dataVals[[All,2]]=If[Length[#]==1,#[[1]],#]&/@dataVals[[All,2]];

(*Create rules for values that are not a normal range. eg kspace index or coil numbers*)
If[MemberQ[lab,"kx"],ruleKx=Thread[("kx"/.dataVals)->(Range["N_kx"/.dataValsN]-1)]];
ruleKy=Thread[("ky"/.dataVals)->(Range["N_ky"/.dataValsN]-1)];
ruleKz=Thread[("kz"/.dataVals)->(Range["N_kz"/.dataValsN]-1)];
ruleCoil=Thread[("chan"/.dataVals)->(Range["N_chan"/.dataValsN]-1)];

(*partition raw data per k-line*)
data=DynamicPartition[data,dataIndex[[-1]]/8];(*longest part*)

(*split the data and index for data type*)
typ=("typ"/.dataVals[[1]]);
pos=Flatten@Position[dataIndex[[1]],#]&/@typ;
dataSplit=Thread[typ->(data[[#]]&/@pos)];
indexSplit=Thread[typ->(dataIndex[[All,#]]&/@pos)];

(*get the number of sample in the data data*)
nSamp=("STD"/.indexSplit)[[-1,1]]/8;
AppendTo[dataValsN,"N_samp"->nSamp];

(*get the data size*)
sizeInd={"N_kx","N_ky","N_kz","N_chan","N_dyn","N_card","N_echo","N_loca","N_mix","N_extr1","N_extr2","N_aver","N_samp"};
sizeInd=Select[sizeInd,MemberQ[dataValsN[[All,1]],#]&];
size=sizeInd/.dataValsN;
(*get the types with dimensions > 1*)
types=Pick[sizeInd,Unitize[size-1],1];

(*process noise data *)
noise="NOI"/.dataSplit;

(*get acepterd sample data and index*)
data=("STD"/.dataSplit);
ind=sizeInd[[;;-2]]/.Thread["N_"<>#&/@lab->Range[Length[lab]]];
indData=("STD"/.indexSplit)[[ind]];

(*reverse even echo*)
echo=1-Mod[indData[[Position[sizeInd,"N_echo"][[1,1]]]],2];
data=MapThread[If[#2==0,Reverse@#,#]&,{data,echo}];

(*convert the index values to array values*)
off=If[MemberQ[lab,"kx"],1,0];
If[MemberQ[lab,"kx"],indData[[1]]=indData[[1]]/.ruleKx;];
indData[[1+off]]=indData[[1+off]]/.ruleKy;
indData[[2+off]]=indData[[2+off]]/.ruleKz;
indData[[3+off]]=indData[[3+off]]/.ruleCoil;
indData=Transpose[indData+1];

(*create squeezed k-space*)
Clear[line];
kspace=ReplacePart[ConstantArray[line,size[[;;-2]]],Thread[indData->data]];(*longest part*)
line=ConstantArray[0.+0.I,nSamp];
kspace=Squeeze[kspace];
size=Dimensions[kspace];
Clear[line];

(*print output*)
Print["Datatypes in data: ",("typ"/.dataVals[[1]])];
Print[Column[Prepend[StringJoin/@Thread[{"  - ",types,": ",ToString/@size}],"The data contains: "]]];

(*define output*)
outHead={Join[dataVals,dataValsN,head],types};(*General*)
outData={kspace,noise};

(*output*)
{outData,outHead}
]


(*split string en convert to expression*)
StringSplitExp[strings_]:=System`Convert`TableDump`ParseTable[StringCases[strings,Except[WhitespaceCharacter]..][[All,;;-2]],{{"",""},{"-","+"},"."},False]


(* ::Subsection:: *)
(*Raw Data manipulation*)


(* ::Subsubsection::Closed:: *)
(*Mean over type*)


SyntaxInformation[MeanType]={"ArgumentsPattern"->{_,_,_.}}

(*Mean over list of values*)
MeanType[list_,type_,posS_List]:=Fold[MeanType,{list,type},posS]
(*Mean such that output and input match*)
MeanType[{list_,type_},posS_String]:=MeanType[list,type,posS]
(*single evaluation of mean*)
MeanType[list_,type_,posS_String]:=Block[{pos},
	(*Print[type];*)
	pos=posS/.Thread[type->Range[Length[type]]];
	(*Print["mean over: ",posS," (",pos")"];*)
	If[IntegerQ[pos],{MeanAt[list,pos],Drop[type,{pos}]},$Failed]
]


(* ::Subsubsection::Closed:: *)
(*Total over type*)


SyntaxInformation[TotalType]={"ArgumentsPattern"->{_,_,_.}}

(*Mean over list of values*)
TotalType[list_,type_,posS_List]:=Fold[TotalType,{list,type},posS]
(*Mean such that output and input match*)
TotalType[{list_,type_},posS_String]:=TotalType[list,type,posS]
(*single evaluation of mean*)
TotalType[list_,type_,posS_String]:=Block[{pos},
	(*Print[type];*)
	pos=posS/.Thread[type->Range[Length[type]]];
	(*Print["mean over: ",posS," (",pos")"];*)
	If[IntegerQ[pos],{TotalAt[list,pos],Drop[type,{pos}]},$Failed]
]


(* ::Subsubsection::Closed:: *)
(*Order K-space*)


SyntaxInformation[OrderKspace]={"ArgumentsPattern"->{_,_,_.}}

(*put kspace in requested order*)
OrderKspace[kspace_,type_,order_]:=OrderKspace[{kspace,type},order]
OrderKspace[{kspace_,type_},order_]:=Block[{mis},
mis=If[!MemberQ[type,#],#,Nothing]&/@order;
	If[mis==={},
		{Transpose[kspace,Flatten[(Position[order,#1]&)/@type]],order},
	Print["the types ",mis," are missing"]
]]


(* ::Subsubsection::Closed:: *)
(*Sagittal Transpose*)


SyntaxInformation[SagitalTranspose]={"ArgumentsPattern"->{_}}

SagitalTranspose[data_]:=(Reverse[Transpose[#1],2]&)/@data;


(* ::Subsection:: *)
(*Fourier Functions*)


(* ::Subsubsection::Closed:: *)
(*FourierShift*)


SyntaxInformation[FourierShift]={"ArgumentsPattern"->{_}}

FourierShift[data_]:=RotateRight[data,Floor[Dimensions[data]/2]];


(* ::Subsubsection::Closed:: *)
(*FourierShift*)


SyntaxInformation[InverseFourierShift]={"ArgumentsPattern"->{_}}

InverseFourierShift[data_]:=RotateLeft[data,Floor[Dimensions[data]/2]];


(* ::Subsubsection::Closed:: *)
(*Shift Data*)


ShiftData[data_,shift_]:=RotateRight[data,Reverse[shift]];


(* ::Subsubsection::Closed:: *)
(*Fourier Functions*)


SyntaxInformation[ShiftedFourier]={"ArgumentsPattern"->{_}}

ShiftedFourier[time_]:=FourierShift[Fourier[time,FourierParameters->{-1,1}]];


SyntaxInformation[ShiftedInverseFourier]={"ArgumentsPattern"->{_}}

ShiftedInverseFourier[spec_]:=InverseFourier[InverseFourierShift[spec],FourierParameters->{-1,1}];


SyntaxInformation[FourierShifted]={"ArgumentsPattern"->{_}}

FourierShifted[time_]:=Fourier[FourierShift[time],FourierParameters->{-1,1}];


SyntaxInformation[InverseFourierShifted]={"ArgumentsPattern"->{_}}

InverseFourierShifted[spec_]:=InverseFourierShift[InverseFourier[spec,FourierParameters->{-1,1}]];


(* ::Subsubsection::Closed:: *)
(*FourierKspace2D*)


FourierKspace2D[kspace_, head_] := Block[{ksPad, dim, p1, p2, shift, kspaceP, imData},
  (*get the oversampling padding*)
  ksPad = Round[({"Y-resolution", "X-resolution"} {"ky_oversample_factor", "kx_oversample_factor"} - {"N_ky", "N_samp"})/2 /. head];
  (*get the final data dimentions*)
  dim = {"Y-resolution", "X-resolution"} /. head;
  (*get the image shift*)
  shift = Total[#] & /@ ({"Y_range", "X_range"} /. head);
  (*get the image padding*){p1, p2} = 
   Round[((({"N_ky", "N_samp"} /. head) - 2 ksPad) - dim)/2];
  ksPad = Transpose@{ksPad, ksPad};
  (*perform the fourie transform*)
  FourierKspace2DI[kspace, ksPad, shift, p1, p2]
  ]


FourierKspace2DI = Compile[{{data, _Complex, 2}, {ksPad, _Integer, 2}, {shift, _Real, 1}, {p1, _Integer, 0}, {p2, _Integer, 0}},
   Block[{dat},
    dat = ArrayPad[data, ksPad];
    dat = FourierShifted[dat];
    dat = ShiftData[dat, shift];
    Chop[dat[[p1 + 1 ;; -p1 - 1, p2 + 1 ;; -p2 - 1]]]
    ], RuntimeAttributes -> {Listable}, RuntimeOptions -> "Speed"];
    

(* ::Subsubsection::Closed:: *)
(*FourierKspaceCSI*)


FourierKspaceCSI[kspace_,head_]:=Block[{ksPad,dim,imPad,shift,kspaceP,imData},
(*get the oversampling padding*)
ksPad=Round[({"Z-resolution","Y-resolution","X-resolution"}{"kz_oversample_factor","ky_oversample_factor","kx_oversample_factor"}-{"N_kz","N_ky","N_kx"})/2/.head];
(*get the final data dimentions*)
dim={"Z-resolution","Y-resolution","X-resolution"}/.head;
(*pad the kaspaces with zeros*)
kspaceP=ArrayPad[#,Transpose@{ksPad,ksPad},0.+0.I]&/@kspace;
(*get the image padding and image shift*)
shift=Total[#]&/@({"Z_range","Y_range","X_range"}/.head);
(*perform the fourie transform*)
imData=ShiftData[FourierShift[FourierShifted[#]],shift]&/@kspaceP
]


(* ::Subsection:: *)
(*Recon Functions*)


(* ::Subsubsection:: *)
(*Coil weighted recon*)


Options[CoilWeightedRecon]={DataShift->0};

CoilWeightedRecon[kspace_,noise_,head_,OptionsPattern[]]:=Block[{
shift,compData,meanData,weights,weightsF,dat,sMat,nMat,dMat,recon
},
shift=OptionValue[DataShift];

(*make Image Data*)
compData=Map[FourierKspace2D[#,head]&,kspace,{-4}];
(*shift the echos to center if needed*)
If[shift=!=0,
compData=Table[If[EvenQ[i],
RotateRight[compData[[i]],{0,0,0,shift[[1]]}],
RotateLeft[compData[[i]],{0,0,0,shift[[2]]}]
],{i,1,Length[compData]}];
];

(*calculate mean signal and complex coil weights*)
Switch[ArrayDepth[compData],
4,
(*Calculate the mean abs signal and determine the weights*)
meanData=SumOfSquares[Abs@compData,OutputWeights->False];
weights=Map[#/meanData&,compData];
,5,
(*Calculate the mean abs signal of the mean echos and determine the weights*)
meanData=SumOfSquares[Abs@Mean[compData],OutputWeights->False];
weights=Map[#/meanData&,Mean[compData]];
];

(*filter weights*)
weightsF=Map[MedianFilter[Re[#],1]+I MedianFilter[Im[#],1]&,weights,{2}];

(*perform reconstruction*)
sMat=TransData[weightsF,"l"];
nMat=Inverse[NoiseCovariance[noise]];
recon=Switch[ArrayDepth[compData],
4,
dMat=TransData[compData,"l"];
MapThread[(1/Sqrt[(Conjugate[#1].nMat.#1)])Conjugate[#1].nMat.#2&,{sMat,dMat},3]
,5,
Transpose[(
dMat=TransData[#,"l"];
MapThread[(1/Sqrt[(Conjugate[#1].nMat.#1)])Conjugate[#1].nMat.#2&,{sMat,dMat},3]
)&/@compData]
];

(*scale to proper values*)
recon=1000.recon/Max[Abs[recon]];

#[recon]&/@{Abs,Arg,Re,Im}
]


(* ::Subsubsection:: *)
(*Coil weighted recon CSI*)


Options[CoilWeightedReconCSI]={HammingFilter->False,CoilSamples->5};

CoilWeightedReconCSI[kspace_,noise_,head_,OptionsPattern[]]:=Block[{CSI,coils,filt,CSIsos,weightsCSI,sMatC,nMatC,csiMat,dMat,CSIcc,spectra},
filt=OptionValue[HammingFilter];

Switch[ArrayDepth[kspace],
4,
CSIcc=TransData[FourierKspaceCSI[ kspace,head],"l"];
,5,
(*perform spatial fourier for CSI*)
CSI=FourierKspaceCSI[ #,head]&/@kspace;
(*perfrom normalization*)
CSI=Transpose[CSI];

(*get weights*)
(*CSIsos=SumOfSquares[Abs@CSI[[1]],OutputWeights\[Rule]False];
weightsCSI=#/CSIsos&/@CSI[[1]];*)
weightsCSI=Mean@Table[
coils=HammingFilterCSI[#,head]&/@CSI[[i]];
CSIsos=SumOfSquares[Abs@coils,OutputWeights->False];
coils=#/CSIsos&/@coils;
(*coils=MedianFilter[Re@#,1]+I MedianFilter[Im@#,1]&/@coils;*)
coils
,{i,1,OptionValue[CoilSamples],1}];

(*perform weightd reconstruction*)
sMatC=TransData[weightsCSI,"l"];
nMatC=Inverse[NoiseCovariance[noise]];
csiMat=TransData[CSI,"l"];

(*perform the recon*)
dMat=TransData[TransData[Transpose[CSI],"l"],"l"];
CSIcc=MapThread[(1/Sqrt[(Conjugate[#1].nMatC.#1)])Conjugate[#1].nMatC.#2&,{sMatC,dMat},3];
];

(*Perform spectral Fourier*)
spectra=Map[FourierShift[Fourier[#,FourierParameters->{-1, 1}]]&,CSIcc,{-2}];
(*Normalize spectra*)
spectra=1000.spectra/Max[Abs[spectra]];

If[filt,spectra=HammingFilterCSI[spectra,head]];

{spectra,TransData[CSIcc,"r"]}
]


(* ::Subsubsection:: *)
(*MakeHammingFilter*)


MakeHammingFilter[{zi_?NumberQ,yi_?NumberQ,xi_?NumberQ}]:=Block[{xs,xe,ys,ye,zs,ze,xm,ym,zm,rans,ham,hx,hy,hz},
(*get ranges*)
{{xs,xe},{ys,ye},{zs,ze}}=rans=Transpose[{-Floor[{xi,yi,zi}/2],Ceiling[{xi,yi,zi}/2]-1}];
{xm,ym,zm}=Max[Abs[#]]&/@rans;
(*make filter*)
Table[
hx=0.54+0.46Cos[(Pi x)/xm];
hy=0.54+0.46Cos[(Pi y)/ym];
hz=0.54+0.46Cos[(Pi z)/zm];
hx hy hz
,{z,zs,ze},{y,ys,ye},{x,xs,xe}]
]


MakeHammingFilter[head_]:=Block[{xs,xe,ys,ye,zs,ze,xm,ym,zm,rans,ham,hx,hy,hz},
(*get ranges*)
{{xs,xe},{ys,ye},{zs,ze}}=rans={"kx_range","ky_range","kz_range"}/.head;
{xm,ym,zm}=Max[Abs[#]]&/@rans;
(*make filter*)
Table[
hx=0.54+0.46Cos[(Pi x)/xm];
hy=0.54+0.46Cos[(Pi y)/ym];
hz=0.54+0.46Cos[(Pi z)/zm];
hx hy hz
,{z,zs,ze},{y,ys,ye},{x,xs,xe}]
]


(* ::Subsubsection:: *)
(*HammingFilter*)


HammingFilterCSI[data_]:=HammingFilterData[data, Dimensions[data][[;;-2]]]

HammingFilterCSI[data_, head_]:=HammingFilterData[data, head]

HammingFilterData[data_]:=HammingFilterData[data, Dimensions[data][[;;-2]]]

HammingFilterData[data_, head_]:=Block[{ham},
ham=MakeHammingFilter[head];
(*perform apodization*)
Switch[ArrayDepth[data],
3,FourierShifted[ham InverseFourierShifted[data]],
4,TransData[FourierShifted[ham InverseFourierShifted[#]]&/@TransData[data,"r"],"l"]
]
]


(* ::Section:: *)
(*End Package*)


End[]

EndPackage[]
