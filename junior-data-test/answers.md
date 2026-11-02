# Questions

## 1. Why place the test task where you did, and what happens to the pipeline if the tests fail?

I named the test task `test_models` and placed it at the end of the DAG, because its tests validate the output of the transformations (those tables only exist once `build_models` has finished). Now, the DAG order is:

```bash
load_data --> build_models --> test_models 
```

To explain the whole process, we first load the raw CSVs `load_data`, then build the tables that cast types and standardise unknown values `build_models`, and finally check that the result meets our expectations `test_models`.

If a test fails, `test_models` returns an error. Looking at how the DAG is made, it waits 5 minutes and retries it once. If it fails again, the task and the whole DAG run are marked as failed, and the logs show which test did not pass. It does not affect at all to the rest of the pipeline, because it is the last task to be executed. However, If we have more tasks after `test_models`, they would not be processed. Also, if `test_models` fails, it is clear that we have to correct the transformations we have made in `build_models` to ensure that the data is cleansed as expected.


## 2. What would your model and your tests do if a new status such as CANCEL started arriving next month? Is that the behaviour you want?

The new status `CANCEL` will be changed to `UNKNOWN` because it is not in the accepted values list, and the tests would not notice that change and still pass each check.

Going step by step, in `stg_visits.sql`, I first cleansed the `visit_status` parameter like this:

```sql
coalesce(nullif(upper(trim(visit_status)), ''), 'UNKNOWN') as initial_visit_status
```

This trims the spaces, converts the text to uppercase, and replaces empty or null values with `UNKNOWN`. Then I make sure the column only contains the allowed values `['OK', 'INCID', 'INFO', 'NOVIS', 'UNKNOWN']` with this case clause:


```sql
case
    when initial_visit_status not in ('OK', 'INCID', 'INFO', 'NOVIS', 'UNKNOWN') then 'UNKNOWN'
    else initial_visit_status
end as visit_status
```

So, if `visit_status` is not equal to any of these values, it is set as `UNKNOWN`. To accept `CANCEL` as another possible value, we have to change this query and include `CANCEL` in the list, like:

```sql
case
    when initial_visit_status not in ('OK', 'INCID', 'INFO', 'NOVIS', 'UNKNOWN', 'CANCEL') then 'UNKNOWN'
    else initial_visit_status
end as visit_status
```

Also, the quality test from `schema.yml` must be changed, including `CANCEL` in the list of values:

```yml
- name: visit_status
data_tests:
    - accepted_values:
        arguments:
        values: ['OK', 'INCID', 'INFO', 'NOVIS', 'UNKNOWN', 'CANCEL']
```


This solution is simple and valid in this kind of example (especially for `raw_visits.csv`), but it is not the behaviour I would want in general. Every new value implies changing the query and tests manually. We have the same problem for typos. Writing mistakes like 'INFFO', will be set as 'UNKNOWN', so we could lose information in this transformation. 


## 3. Why mark missing statuses as UNKNOWN rather than dropping those rows? Is there a case where dropping them would be better?

I think that marking missing statuses as `UNKNOWN` is generally better than dropping the rows, because a missing status does not make the rest of the row useless. The visit still happened, and the other columns could be correct. Dropping the row would throw away that information and would change the results of any analysis that does not depend on the status.

For example, if we want to know which campaign is the most frequent in the database, dropping the rows with a missing status would undercount the campaigns that have more missing statuses, and the analysis would be skewed. With the mark `UNKNOWN`, every visit is still counted, and anyone who needs to exclude them can simply filter `visit_status != 'UNKNOWN'` in their own query.

However, there are cases where I would rather drop these rows. When the metrics are only meaningful with a known status, or when the row is unusable as a whole, these records add noise to the analysis, so I would exclude them.


# Additional information

A virtual environment has been created to both install all the requirements and avoid libraries conflicts (venv folder).

```bash
python -m venv venv
.\venv\Scripts\activate
```