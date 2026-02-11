-- Create equipment table
CREATE TABLE IF NOT EXISTS equipment (
    id SERIAL PRIMARY KEY,
    equipment_id VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create usage logs table
CREATE TABLE IF NOT EXISTS usage_logs (
    id SERIAL PRIMARY KEY,
    equipment_id INTEGER REFERENCES equipment(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    hours DECIMAL(10,2) NOT NULL,
    cost DECIMAL(10,2) NOT NULL,
    revenue DECIMAL(10,2) NOT NULL,
    profit DECIMAL(10,2) GENERATED ALWAYS AS (revenue - cost) STORED,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_usage_logs_equipment ON usage_logs(equipment_id);
CREATE INDEX IF NOT EXISTS idx_usage_logs_date ON usage_logs(date);
CREATE INDEX IF NOT EXISTS idx_equipment_equipment_id ON equipment(equipment_id);

-- Insert sample data
INSERT INTO equipment (equipment_id, name) VALUES 
    ('10125-DL', 'Int''l 2275 Dump Truck'),
    ('10126-EX', 'CAT 320 Excavator'),
    ('10127-LD', 'John Deere Loader')
ON CONFLICT (equipment_id) DO NOTHING;

INSERT INTO usage_logs (equipment_id, date, hours, cost, revenue) VALUES 
    (1, '2025-01-15', 8.0, 200.00, 800.00),
    (1, '2025-01-16', 6.5, 150.00, 650.00),
    (1, '2025-01-17', 7.0, 175.00, 700.00),
    (2, '2025-01-15', 4.0, 100.00, 400.00),
    (2, '2025-01-16', 5.5, 137.50, 550.00),
    (3, '2025-01-15', 6.0, 120.00, 480.00)
ON CONFLICT DO NOTHING;