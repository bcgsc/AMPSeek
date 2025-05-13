import pandas as pd
import sys

args = sys.argv
amplify_res = pd.read_csv(args[1], sep='\t')
amplify_res = amplify_res.rename(columns={'Sequence_ID': 'ID', 'Probability_score':'AMPlify Score',  'Prediction':'Bioactivity Prediction'})
amplify_res = amplify_res[['ID', 'Sequence', 'AMPlify Score', 'Bioactivity Prediction', 'Charge', 'Length']]
tamper_res = pd.read_csv(args[2])
tamper_res = tamper_res.rename(columns={'id': 'ID', 'sequence':'Sequence', 'score':'tAMPer Score', 'prediction':'Toxicity Prediction'})
tamper_res['Toxicity Prediction'] = tamper_res['Toxicity Prediction'].apply(lambda x: 'Toxic' if x==1 else 'Non-toxic')
compiled_res = pd.merge(amplify_res, tamper_res, how='inner')
compiled_res.to_csv(sys.argv[3])