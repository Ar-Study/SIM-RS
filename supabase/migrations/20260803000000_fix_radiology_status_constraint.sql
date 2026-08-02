ALTER TABLE radiology_orders
    DROP CONSTRAINT IF EXISTS radiology_orders_status_check;

ALTER TABLE radiology_orders
    ADD CONSTRAINT radiology_orders_status_check
    CHECK (status IN ('ordered', 'in_progress', 'completed', 'cancelled'));
