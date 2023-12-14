#+ echo=FALSE
if(!require(NGLVieweR))install.packages("NGLVieweR")
if(!require(readr)) install.packages("readr")
if(!require(tidyverse)) install.packages("tidyverse")
if(!require(pandoc)) install.packages("pandoc")
if(!require(common)) install.packages("common")
if(!require(common)) install.packages("common")
if(!require(htmltools)) install.packages("htmltools")
if(!require(stringr)) install.packages("stringr")
if(!require(rmarkdown)) install.packages("rmarkdown")
if(!require(knitr)) install.packages("knitr")
library(htmltools)
library(stringr)
library(readr)
library(remotes)
library(tidyverse)
library(pandoc)
library(NGLVieweR)
library(stringr)

# arguments
args = commandArgs(trailingOnly=TRUE)
amplify_path <- args[1]
pdb_dir_path <- args[2]
#tamper_path <- args[3]
output_path <- args[3]

#'
#' ---
#' title: "AMPSeek Report"
#' output:
#'   html_document:
#'     keep_tex: true
#'     self_contained: false
#' ---



#' # AMPSeek Report
#' The report has been generated from the files:
{{amplify_path}}

#+echo=FALSE
amplify_results<-read_tsv(amplify_path,show_col_types = FALSE)
num_of_amps <- nrow(amplify_results)
show_protein <- function(protein) {
  return(div(protein))
}
#'and it has
{{num_of_amps}}
#' of prediction of AMP activity, fold structure, and toxicity.

#+echo=FALSE, results="asis", include=TRUE
amplify_row <- amplify_results[1,]

cat('\n### ID:\n ', toString(amplify_row["Sequence_ID"]), '\n')
cat('\n### Sequence:\n ', toString(amplify_row["Sequence"]), '\n')
cat('\n### Properties:\n ', "Length:", toString(amplify_row["Length"]), ", Charge: ", toString(amplify_row["Charge"]), '\n')
cat('\n### AMP activity:\n ', toString(amplify_row["Prediction"]), ' with overall probability of',toString( amplify_row["Probability_score"] ), '\n')
cat('\n### Sub-model probability scores:\n')
model_probs <- amplify_row%>%select(c(5,6,7,8,9))

pivoted <- model_probs %>% 
  pivot_longer(everything()) 

print(ggplot(pivoted, aes(x=name, y=value)) +
        geom_bar(stat="identity") +
        scale_x_discrete(guide = guide_axis(angle = 90)) +
        geom_text(aes(label = value), vjust = 1.5, colour = "white") )

cat('\n\n### Attention Distribution along the sequence:\n')
attention <- amplify_row["Attention"]
attention <- unlist(str_split(attention, ","))
attention[1] <- str_sub(attention[1], 2, str_length(attention[1]))
attention[-1] <- str_sub(attention[-1], 1, str_length(attention[-1])-1)
attention <- as.numeric(attention)
seq <- unlist(str_split(toString(amplify_row["Sequence"]), ""))
num<- 1:str_length(toString(amplify_row["Sequence"]))
attention_df <- data.frame(number=num, attention_score=attention, amino_acid=seq)
print(ggplot(attention_df, aes(x=number, y=attention_score)) +
        geom_bar(stat="identity", aes(fill=amino_acid)) +
        geom_text(aes(label = amino_acid), vjust = 1.5, colour = "white")+
        xlab("The sequential order of the aminoacid")+
        ylab("Attention Score")+
        guides(fill=guide_legend(title="Amino Acid Type")))


pdb_pattern <- paste(amplify_row["Sequence_ID"],"*rank_001_*.pdb", sep="")
pdb_file <- file.find(path=pdb_dir_path, pattern=pdb_pattern, up=0, down=0)[1]

cat('\n\n### Best Protein Structure Prediction:\n')
NGLVieweR(pdb_file)%>%addRepresentation("cartoon")




#+ eval=FALSE, echo=FALSE
rmarkdown::render('report.R',output_file=output_path)