# %% [markdown]
# ## Ćwiczenie 1
# %%
import arff
import pandas as pd
import numpy as np

def load_arff(path):
    with open(path, "r", encoding="utf-8") as f:
        data = arff.load(f)

    df = pd.DataFrame(data["data"], columns=[a[0] for a in data["attributes"]])
    return df
# %%
from sklearn.preprocessing import LabelEncoder
import numpy as np

def prepare(df):
    df = df.copy()

    y = df["status_pozyczki"].values
    y = np.array([1 if str(v) in ["zły", "z?y"] else 0 for v in y])

    X = df.drop(columns=["status_pozyczki"])

    encoders = {}

    for col in X.columns:
        X[col] = X[col].astype(str).str.replace("'", "").fillna("missing")

        le = LabelEncoder()
        X[col] = le.fit_transform(X[col])

        encoders[col] = le

    return X.values.astype(np.int64), y
# %%
from sklearn.metrics import confusion_matrix, roc_auc_score

def gmean(tp, tn, fp, fn):
    tpr = tp / (tp + fn) if (tp + fn) else 0
    tnr = tn / (tn + fp) if (tn + fp) else 0
    return np.sqrt(tpr * tnr), tpr, tnr
# %%
from sklearn.model_selection import StratifiedKFold
from sklearn.base import clone

def evaluate(model, X, y, folds=10, repeats=3):

    cm_sum = np.zeros((2, 2))

    acc_sum = 0
    tpr_sum = 0
    tnr_sum = 0
    gmean_sum = 0
    auc_sum = 0

    for r in range(repeats):

        skf = StratifiedKFold(n_splits=folds, shuffle=True, random_state=r)

        for train_idx, test_idx in skf.split(X, y):

            X_train, X_test = X[train_idx], X[test_idx]
            y_train, y_test = y[train_idx], y[test_idx]

            clf = clone(model)
            clf.fit(X_train, y_train)

            y_pred = clf.predict(X_test)

            cm = confusion_matrix(y_test, y_pred, labels=[0, 1])
            tn, fp, fn, tp = cm.ravel()

            cm_sum += cm

            acc_sum += (tp + tn) / (tp + tn + fp + fn)

            g, tpr, tnr = gmean(tp, tn, fp, fn)

            tpr_sum += tpr
            tnr_sum += tnr
            gmean_sum += g

            if hasattr(clf, "predict_proba"):
                probs = clf.predict_proba(X_test)[:, 1]
                auc_sum += roc_auc_score(y_test, probs)
            else:
                auc_sum += 0.5

    total = folds * repeats

    print("=== RESULTS ===")
    print("Confusion matrix:")
    print(cm_sum / total)

    print("Accuracy:", acc_sum / total)
    print("TP rate:", tpr_sum / total)
    print("TN rate:", tnr_sum / total)
    print("GMean:", gmean_sum / total)
    print("AUC:", auc_sum / total)
# %%
from sklearn.dummy import DummyClassifier
from sklearn.naive_bayes import CategoricalNB
from sklearn.tree import DecisionTreeClassifier
from sklearn.svm import SVC
from sklearn.neural_network import MLPClassifier
# %%
df = load_arff("XXXXXXL4 1.arff")
X, y = prepare(df)
# %% [markdown]
# ## Ćwiczenie 2
# %%
evaluate(DummyClassifier(strategy="most_frequent"), X, y)
# %%
evaluate(CategoricalNB(), X, y)
# %%
evaluate(DecisionTreeClassifier(), X, y)
# %%
evaluate(SVC(probability=True), X, y)
# %%
evaluate(MLPClassifier(hidden_layer_sizes=(10,10), max_iter=500), X, y)