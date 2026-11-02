-- Visit create_at date test
-- A visit created after today usually points to a loading error.

select
    visit_id,
    created_at
from {{ ref('stg_visits') }}
where created_at > current_date
