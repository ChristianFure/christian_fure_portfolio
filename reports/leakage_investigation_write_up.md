# Data Leakage Investigation

---

## 1. Executive Summary

&emsp;During the model evaluation portion of my project, the initial results came back suspiciously strong. They felt too good to be true, which prompted a full audit of features and the label pipeline. There were a few things that were found during the audit that were actual mistakes. Those were an incorrectly defined readmission label, patient-level leakage across train/test split, and one of the features used information it wasn't supposed to have access to. All problems were fixed, but model performance remained high. From there, a shuffled-label sanity test and an out-of-sample holdout cohort were checked against the model. Both of these tests were run, and nothing changed, which meant the performance reflected genuine signal and not a leak. After reading into Synthea's documentation, the most plausible explanation would be that, due to the rule-based generative logic used to create the synthetic data, the patients' histories are simply more learnable than real-world clinical data, and it lacks the nuances of real-world data. This was then listed as a known limitation of our model, so that it isn't assumed that the results of this model are reproducible on real patient data.

---

## 2. Why We Went Looking

&emsp;Early evaluation metrics on the readmission model were high enough to be a red flag rather than a milestone. In applied healthcare ML, real-world 30-day readmission models — built on messy, high-noise clinical data — rarely reach the discrimination levels the first-pass model was producing. Rather than take that performance at face value, the working assumption shifted from "the model is good" to "something in the pipeline is probably wrong," and the investigation started from the two most common sources of inflated performance in healthcare ML: label construction and train/test contamination.

&emsp;Evaluation metrics on the model were high enough to be more of a red flag than a milestone to celebrate, without validation. In real-world applied healthcare ML, which is built on messy, high-noise clinical data would rarely reach the performance our model was producing. Rather than just looking at the incredible performance and taking it at face value, the goal shifted to proving the model to be wrong. If everything in possible was done to prove this model wrong and it came back innocent, then you could only assume the model was showing genuine signal.

---

## 3. Bug #1 — Label Definition Error

**What it was:** The `readmit_30d` label was originally constructed by measuring the gap between one admission's start date and the _next_ admission's start date (admission-to-admission), rather than the gap between a stay's _discharge_ date and the next admission (discharge-to-admission).

**Why it's a problem:** If admission-to-admission is the gap being compared in the cohort to determine who readmits, then the readmission gap is systemically shortened and doesn't truly represent the 30-day window it is intended to, since length of stay itself leaks into the label.

**How it was caught:** Checking samples of labeled positive cases against their `stay_start`/`stay_end`/`days_til_next_admission` values in `features.cohort` is what brought this issue to light.

**The fix:** Recomputed `readmit_30d` using `stay_end` (discharge date) as the anchor, measuring the gap to the next `stay_start` for that patient.

---

## 4. Bug #2 — Patient-Level Train/Test Leakage

**What it was:** The original train/test split was performed at the _stay_ level rather than the _patient_ level. Since some patients have multiple inpatient stays in the dataset, this meant the same patient could appear in both the training and test sets.

**Why it's a problem:** Models can pick up on patient-specific patterns (a particular combination of chronic conditions, utilization habits, or even near-duplicate feature rows across a patient's stays) that have nothing to do with generalizable readmission risk. This inflates test-set performance because the model has effectively already "seen" that patient during training.

It becomes a problem because complex models like the one used in this project (XGBoost) can pick up on patient-specific patterns. A particular combination of chronic conditions, utilization habits, etc. can lead the model to figure out who a patient is. This could inflate test-set performance because the model has already "seen" this patient before during the training portion.

**The fix:** Switched to `GroupShuffleSplit` for the train/test split and `StratifiedGroupKFold` for cross-validation, both grouped on `patient_id`, guaranteeing that all stays belonging to a given patient fall entirely within one split.

---

## 5. Bug #3 — Future Diagnosis Leakage in `condition_features`

**What it was:** The CTE feeding `active_conditions` (and related flags like `has_heart_failure`, `has_diabetes`) in `features.condition_features` was pulling from the full condition history available at query time, rather than being constrained to conditions active as of the stay's discharge date. In practice, this meant some patients were getting flagged for conditions they had not been diagnosed with yet.

**Why it's a problem:** The model was "seeing the future" because it was getting access to information that wouldn't actually be available at the time of discharge.

**How it surfaced:** It surfaced during SHAP feature importance analysis when `active_conditions` showed up near the top of the features. All top features were investigated, so this wasn't initially anything out of the ordinary.

**The fix:** Fixed the data boundaries on the CTE that was querying `active_conditions`. The upper-bound date clause was incorrectly set.

---

## 6. Validating the Fix Was Real

- **Shuffled-label sanity test:** `readmit_30d` was randomly shuffled to break any real relationship between the features and outcome. The model was retrained on the shuffled labels, and performance dropped to approximately chance level, which confirms the model wasn't picking up on some structural artifact of the features table independent of the label.
- **Independent holdout cohort:** An entirely new patient cohort was generated for this test. It was held out entirely from training and hyperparameter tuning. Performance was consistent with the primary test set, indicating the result wasn't an artifact of a particular split.

---

## 7. Why Performance Stayed High — The Synthea Explanation

&emsp;With all three known leaks fixed and sanity checks passed, the last thing to do was to look at Synthea to blame. The most plausible explanation was that Synthea's rule-based generative logic system generates data that high-powered models like XGBoost are able to detect the underlying patterns of. Relationships between conditions, utilization patterns, and outcomes are much more deterministic than what's typically seen in real-world noisy EHR/claims data. That inherently makes the patient population more learnable, regardless of what modeling approach is used. This was listed as a known limitation of the project rather than an unresolved concern. 

---

## 8. Lessons Learned / Process Takeaways

- **Unexpectedly good results are a red flag that needs to be investigated, not a reason to celebrate.** Suspiciously strong early metrics were the entire reason this audit happened. Simply trusting a strong performance for the sake of how it looks on paper is a very bad practice. I believe proving the model innocent is a very important step to take before ever considering it production-ready.
- **Always group-split on the entity that can legitimately repeat.** Any dataset with multiple rows per patient should be grouped on that ID, not a naive random row-level split.
- **Temporal boundaries need to be enforced explicitly, not assumed.** A CTE that "should" only return past data will happily return future data too if there's no explicit date filter. Making sure features are bounded properly is a crucial step in feature engineering.
- **Let feature importance be a diagnostic tool, not just a results artifact.**  Every single feature that stood out from the rest was investigated. They were treated as top suspects until they were proven innocent, meaning their signal was real and wasn't a result of leakage.
- **Validate a fix the same way you'd validate a model.** Shuffled-label tests and independent holdouts aren't just for the original model build. They're just as useful for confirming a bug fix actually worked.

---
