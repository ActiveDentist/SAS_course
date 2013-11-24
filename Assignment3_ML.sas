/*
ML
Programming Assignment 2
*/

/* 5 - Create and Apply formats to the Sex and Race Variables, also contains formats for Assignment 2 */
proc format;
	value Sex  
		1 = 'Female' 
		2 = 'Male';
	value Race 
		1 = 'Asian'
		2 = 'Black'
		3 = 'Caucasian'
		4 = 'other';
	value Race_new
		1,2,4,. = 'Other'
		3 = 'White';
	value Weight
		low-200  = 'Less than 200'
		200-<300 = '200 to < 300'
		300-high = '>= 300'
			   . = 'Missing';	
	value wt_cat 
		1 = '<= Median Weight'
		2 = '> Median Weight';	
run;

data STUDY;
/*   1 - Read the data in suppTRP-1062.txt */
	infile "/courses/u_ucsd.edu1/i_536036/c_629/suppTRP-1062.txt" MISSOVER dsd;	
	input Site: $1.
  		  Pt  : $2.
  		  Sex
   		  Race
  		  Dosedate: mmddyy8.
  		  Height
  		  Weight
  		  Result1
  		  Result2
  		  Result3;
	format Dosedate date9.
  		   Sex Sex.
 		   Race Race.;

/* 6 - create descriptive labels for : Site, Pt, Doselot, prot_amend, Limit, site_name */

	label Site = 'Study Site'
	 	  Pt = 'Patient'
		  Doselot = 'Dose Lot'
		  prot_amend = 'Protocol Amendment'	
		  Limit = 'Lower Limit of Detection'
		  site_name = 'Site Name';

/* 2 - Using IF-THEN statements and date constants, create a new variable called Doselot */ 
	if	Dosedate ge '01JAN1997'd and Dosedate le '31DEC1997'd then Doselot ='S0576';
	else if Dosedate ge '01JAN1998'd and Dosedate le '10JAN1998'd then Doselot ='P1122';
	else if Dosedate ge '11JAN1998'd then Doselot ='P0526';

/* 3 - Create two new variables called prot_amend, and limit that meet the criteria listed */
	if Doselot = 'P0526' then do;
	   prot_amend = 'B';
	   if Sex = 1 then Limit = 0.03;
	   else Limit = 0.02;
	end;
    if Doselot = 'P1122' or Doselot = 'S0576' then do;
	   prot_amend = 'A';
	   Limit = 0.02;
	end;

/* 4 - Using a select statement, use the variable Site to create a new variable called site_name which contains the name of the study site */
	length site_name $26.;
	select (Site);
		when ('J') site_name = 'Aurora Health Associates';
		when ('Q') site_name = 'Omaha Medical Center';
		when ('R') site_name = 'Sherwin Heights Healthcare';
		otherwise;
	end;
run;
/* 7 - Sort and Merge datasets STUDY and DEMOG1062 */
LIBNAME Class '/courses/u_ucsd.edu1/i_536036/c_629/saslib';

proc sort data=Class.DEMOG1062 out=demog;
	by pt site;
run;

proc sort data=STUDY;
	by Pt Site;
run;

data PAT_INFO;
	merge STUDY demog;
	by Pt Site;

	/* 8 create Site-Patient */
	if not missing(Pt) and not missing(Site) then pt_id = Site || '-' || Pt;
	label pt_id = 'Site-Patient';
	/* 9 create Quarter */
	if not missing(Dosedate) then dose_qtr = cats('Q',QTR(Dosedate));
	/* 10 Create Mean_Result */
	mean_result = mean(Result1,Result2,Result3);
	/* 11 Create BMI */
    if not missing(Height) and not missing(Weight) then BMI = Weight / (Height**2) * 703;
	/* 12 Create Estimated End Date*/
	select(prot_amend);
		when ('A') est_end = Dosedate + 120; 	
		when ('B') est_end = Dosedate +  90;
		otherwise;
	end;
	label est_end = 'Estimated Termination Date';
	format est_end mmddyy10. mean_result 8.2 BMI 8.1;
run;

/* 13 - using Proc Print to match data in text output */

proc sort data=PAT_INFO;
	by Site site_name;
run;

proc print data=PAT_INFO double label;	
	by Site site_name;
	id Site site_name;
	var Pt AGE Sex Race Height Weight Dosedate Doselot;
	where Weight gt 250;
	label Site = "Study Site"
		  site_name = "Site Name"
		  Pt   	   = "Patient"	
		  AGE  	   = "Age"
		  Dosedate = "Date of First Dose"
		  Doselot  = "Dose Lot Number";
	format Dosedate MMDDYY10.;
	title1 'Listing of Baseline Patient Information for Patients Having Weight > 250';	
run;

title;

/* 14 - Using PAT_INFO for Proc Means*/

proc means data=PAT_INFO
	n nway mean stderr min max maxdec=1;
	class sex;
	var Result1 Result2 Result3 Height Weight;
	output out=PAT_INFO_ITEM14(keep=sex med_wt)median(weight) = med_wt;
run;

/* 15 Median Weight Category */

proc sort data=PAT_INFO;
	by sex;
run;

proc sort data=PAT_INFO_ITEM14;
	by sex;
run;

data PAT_INFO_ITEM15;
	merge PAT_INFO PAT_INFO_ITEM14;
	by sex;
	select;
		when (Weight > med_wt) wt_cat = 2;
		otherwise wt_cat = 1;
	end;
	format wt_cat wt_cat.;
	label wt_cat = 'Median Weight Category';
run;

/* 16 - using item 15 for Proc Freq */

proc freq data=PAT_INFO_ITEM15;
	tables Doselot med_wt;
	tables Race * Weight  / missing;
	format Race Race_new. Weight Weight.;
run;
	
/* 17 - Proc Univariate */

proc univariate data=PAT_INFO_ITEM15;
	by med_wt;
	var Height;
	id pt_id;
run;

/* 18 - Proc Report Summary */

options missing="";

title2 "Summary of Mean Analyte Results by Weight Category and Sex";
proc report nowd headline;
	column wt_cat sex site_name, (Result1-Result3);
	define wt_cat / display "Weight Category" group;
	define sex / left group;
	define site_name / order across "-Site-";
	define Result1 / analysis mean "Mean Result1" format=8.2;
	define Result2 / analysis mean "Mean Result2" format=8.2;
	define Result3 / analysis mean "Mean Result3" format=8.2;
run;
title;

title2 "Listing of Baseline Patient Characteristics";
proc report data=PAT_INFO_ITEM15 headskip nowd;
	column site pt_id dosedate Age Sex Race wt_cat BMI BMI_cat Result1 Result2 abs_change;
	define site / group noprint;
	define pt_id / "Patient" group width=7;
	define dosedate / "Dose Date" left format=mmddyy10. width=10;
	define Age / display "Age" width=3;
	define Sex / display "Sex" left;
	define Race / display "Race" left;
	define wt_cat / display "Weight Category" width=16;
	define BMI / display right width=4;
	define BMI_cat / computed "BMI Category";
	define Result1 / display "Analyte Result 1";
	define Result2 / display "Analyte Result 2";
	define abs_change / computed "Absolute Change";

	compute after site;
		line '';
	endcomp;
	
	compute BMI_cat / character length=12;
		if BMI lt 18.5 then BMI_cat = 'Underweight';
		else if BMI lt 25 then BMI_cat = 'Normal';
		else if BMI lt 30 then BMI_cat = 'Overweight';
		else BMI_cat = 'Obese';
	endcomp;

	compute abs_change;
		abs_change = Result2 - Result1;
	endcomp;
run;	
