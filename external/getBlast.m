function blastStructure=getBlast(organismID,fastaFile,modelIDs,refFastaFiles)
% getBlast
%   Performs a bidirectional BLASTp between the organism of interest and a
%   set of template organisms.
%
%   organismID      the id of the organism of interest. This should also
%                   match with the id supplied to getModelFromHomology
%   fastaFile       a FASTA file with the protein sequences for the
%                   organism of interest
%   modelIDs        a cell array of model id:s. These must match the
%                   "model.id" fields in the "models" structure if the output
%                   is to be used with getModelFromHomology
%   refFastaFiles   a cell array with the paths to the corresponding FASTA
%                   files
%
%   blastStructure  structure containing the bidirectional homology
%                   measurements which are used by getModelFromHomology
%
%   NOTE: This function calls BLASTp to perform a bidirectional homology
%   test between the organism of interest and a set of other organisms
%   using standard settings. If you would like to use other homology
%   measurements, please see getBlastFromExcel.
%
%   Usage: blastStructure=getBlast(organismID,fastaFile,modelIDs,...
%           refFastaFiles)
%
%   Rasmus Agren, 2014-01-08
%

%Everything should be cell arrays
organismID=cellstr(organismID);
fastaFile=cellstr(fastaFile);
modelIDs=cellstr(modelIDs);
refFastaFiles=cellstr(refFastaFiles);

blastStructure=[];

%Get the directory for RAVEN Toolbox. This may not be the easiest or best
%way to do this
[ST, I]=dbstack('-completenames');
ravenPath=fileparts(fileparts(ST(I).file));

%Construct databases and output file
tmpDB=tempname;
outFile=tempname;

%Create a database for the new organism and blast each of the
%refFastaFiles against it
if isunix
    if ismac
        binEnd='.mac';
    else
        binEnd='';
    end
elseif ispc
    binEnd='';
else    dispEM('Unknown OS, exiting.')
    return
end
[status output]=system(['"' fullfile(ravenPath,'software','blast-2.4.0+',['makeblastdb' binEnd]) '" -in "' fastaFile{1} '" -out "' tmpDB '" -dbtype "prot"']);

for i=1:numel(refFastaFiles)
    fprintf(['BLASTing "' modelIDs{i} '" against "' organismID{1} '"..\n']);
    [status output]=system(['"' fullfile(ravenPath,'software','blast-2.4.0+',['blastp' binEnd]) '" -query "' refFastaFiles{i} '" -out "' outFile '_' num2str(i) '" -db "' tmpDB '" -evalue 10e-5 -outfmt "10 qseqid sseqid evalue pident length"']);
 end
delete([tmpDB '*']);

%Then create a database for each of the reference organisms and blast
%the new organism against them
for i=1:numel(refFastaFiles)
    fprintf(['BLASTing "' organismID{1} '" against "' modelIDs{i} '"..\n']);
    [status output]=system(['"' fullfile(ravenPath,'software','blast-2.4.0+',['makeblastdb' binEnd]) '" -in "' refFastaFiles{i} '" -out "' tmpDB '" -dbtype "prot"']);
    [status output]=system(['"' fullfile(ravenPath,'software','blast-2.4.0+',['blastp' binEnd]) '" -query "' fastaFile{1} '" -out "' outFile '_r' num2str(i) '" -db "' tmpDB '" -evalue 10e-5 -outfmt "10 qseqid sseqid evalue pident length"']);
     delete([tmpDB '*']);
end

%Done with the BLAST, do the parsing of the text files
for i=1:numel(refFastaFiles)*2
    tempStruct=[];
    if i<=numel(refFastaFiles)
        tempStruct.fromId=modelIDs{i};
        tempStruct.toId=organismID{1};
        A=importdata([outFile '_' num2str(i)]);
    else
        tempStruct.fromId=organismID{1};
        tempStruct.toId=modelIDs{i-numel(refFastaFiles)};
        A=importdata([outFile '_r' num2str(i-numel(refFastaFiles))]);
    end
    tempStruct.fromGenes=A.textdata(:,1);
    tempStruct.toGenes=A.textdata(:,2);
    tempStruct.evalue=A.data(:,1);
    tempStruct.identity=A.data(:,2);
    tempStruct.aligLen=A.data(:,3);
    blastStructure=[blastStructure tempStruct];
end

%Remove the old tempfiles
delete([outFile '*']);
end
