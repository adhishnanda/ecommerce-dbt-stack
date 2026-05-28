{% macro is_weekday(date_column) %}
    -- BigQuery DAYOFWEEK: 1 = Sunday, 2 = Monday … 6 = Friday, 7 = Saturday
    extract(dayofweek from {{ date_column }}) between 2 and 6
{% endmacro %}
