-- product image table

CREATE TABLE product_image (
    image_id INT AUTO_INCREMENT PRIMARY KEY,
    product_item_id INT NOT NULL,
    image_url VARCHAR(500) NOT NULL,
    image_alt_text VARCHAR(255),
    display_order SMALLINT DEFAULT 0,
    is_primary BOOLEAN DEFAULT FALSE,
    image_width INT,
    image_height INT,
    file_size_kb INT,
    file_type VARCHAR(10),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    caption VARCHAR(255),
    copyright_info VARCHAR(255),
    CONSTRAINT fk_product_item FOREIGN KEY (product_item_id) 
        REFERENCES product_item(product_item_id) ON DELETE CASCADE,
    CONSTRAINT chk_file_type CHECK (file_type IN ('jpg', 'jpeg', 'png', 'webp', 'gif', 'svg'))
);

CREATE INDEX idx_product_image_product_item_id ON product_image(product_item_id);

-- Ensure only one primary image per product
CREATE UNIQUE INDEX idx_product_primary_image 
ON product_image(product_item_id) 
WHERE is_primary = TRUE;

-- Function to update timestamp on record change
CREATE OR REPLACE FUNCTION update_product_image_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update the updated_at timestamp
CREATE TRIGGER trg_product_image_timestamp
BEFORE UPDATE ON product_image
FOR EACH ROW
EXECUTE FUNCTION update_product_image_timestamp();

-- Function to ensure only one primary image
-- Only one is_primary per product_item_id
-- Only one is_primary per product_item_id
DELIMITER $$
CREATE TRIGGER trg_single_primary_image BEFORE INSERT ON product_image
FOR EACH ROW
BEGIN
  IF NEW.is_primary = TRUE THEN
    UPDATE product_image SET is_primary = FALSE
    WHERE product_item_id = NEW.product_item_id;
  END IF;
END $$
DELIMITER ;

-- Trigger to maintain single primary image
CREATE TRIGGER trg_single_primary_image
BEFORE INSERT OR UPDATE OF is_primary ON product_image
FOR EACH ROW
WHEN (NEW.is_primary = TRUE)
EXECUTE FUNCTION ensure_single_primary_image();


-- product category table

CREATE TABLE product_category (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    parent_category_id INT,
    category_name VARCHAR(100) NOT NULL,
    category_description TEXT,
    category_image_url VARCHAR(500),
    url_slug VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    display_order INT DEFAULT 0,
    meta_title VARCHAR(255),
    meta_description VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_parent_category FOREIGN KEY (parent_category_id) 
        REFERENCES product_category(category_id) ON DELETE RESTRICT,
    CONSTRAINT uq_category_name UNIQUE (category_name),
    CONSTRAINT uq_url_slug UNIQUE (url_slug)
);

CREATE INDEX idx_product_category_parent ON product_category(parent_category_id);
CREATE INDEX idx_product_category_slug ON product_category(url_slug);

-- Function for updating timestamp
CREATE OR REPLACE FUNCTION update_product_category_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update timestamp
CREATE TRIGGER trg_product_category_timestamp
BEFORE UPDATE ON product_category
FOR EACH ROW
EXECUTE FUNCTION update_product_category_timestamp();

-- Function to format URL slugs
CREATE OR REPLACE FUNCTION format_category_slug()
RETURNS TRIGGER AS $$
BEGIN
    -- Replace spaces with hyphens, remove special characters, convert to lowercase
    NEW.url_slug = LOWER(REGEXP_REPLACE(REGEXP_REPLACE(NEW.category_name, '[^a-zA-Z0-9\s]', '', 'g'), '\s+', '-', 'g'));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-format URL slugs on insert if not provided
CREATE TRIGGER trg_format_category_slug
BEFORE INSERT ON product_category
FOR EACH ROW
WHEN (NEW.url_slug IS NULL OR NEW.url_slug = '')
EXECUTE FUNCTION format_category_slug();

-- Recursive CTE function to get full category path
CREATE OR REPLACE FUNCTION get_category_path(p_category_id INTEGER)
RETURNS TEXT AS $$
DECLARE
    path_result TEXT;
BEGIN
    WITH RECURSIVE category_path AS (
        SELECT category_id, category_name, parent_category_id, category_name::TEXT AS path
        FROM product_category
        WHERE category_id = p_category_id
        
        UNION ALL
        
        SELECT pc.category_id, pc.category_name, pc.parent_category_id, 
               pc.category_name || ' > ' || cp.path
        FROM product_category pc
        JOIN category_path cp ON pc.category_id = cp.parent_category_id
    )
    SELECT path INTO path_result
    FROM category_path
    WHERE parent_category_id IS NULL;
    
    RETURN path_result;
END;
$$ LANGUAGE plpgsql;



-- product_item table

CREATE TABLE product_item (
    product_item_id INT AUTO_INCREMENT PRIMARY KEY,
    brand_id INT NOT NULL,
    category_id INT NOT NULL,
    product_name VARCHAR(255) NOT NULL,
    product_description TEXT,
    product_specs JSON,
    sku VARCHAR(50) NOT NULL,
    url_slug VARCHAR(255) NOT NULL,
    base_price DECIMAL(15,2) NOT NULL,
    currency_code CHAR(3) DEFAULT 'USD',
    tax_rate DECIMAL(5,2) DEFAULT 0.00,
    weight_kg DECIMAL(10,3),
    length_cm DECIMAL(10,2),
    width_cm DECIMAL(10,2),
    height_cm DECIMAL(10,2),
    is_featured BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    stock_status VARCHAR(20) DEFAULT 'in_stock',
    meta_title VARCHAR(255),
    meta_description VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    release_date DATE,
    discontinued_date DATE,
    average_rating DECIMAL(3,2),
    review_count INT DEFAULT 0,
    search_keywords JSON,
    CONSTRAINT fk_brand FOREIGN KEY (brand_id) 
        REFERENCES brand(brand_id) ON DELETE RESTRICT,
    CONSTRAINT fk_category FOREIGN KEY (category_id) 
        REFERENCES product_category(category_id) ON DELETE RESTRICT,
    CONSTRAINT uq_product_sku UNIQUE (sku),
    CONSTRAINT uq_product_url_slug UNIQUE (url_slug),
    CONSTRAINT chk_stock_status CHECK (stock_status IN ('in_stock', 'out_of_stock', 'backorder', 'discontinued', 'coming_soon')),
    CONSTRAINT chk_rating CHECK (average_rating BETWEEN 0 AND 5 OR average_rating IS NULL)
);

CREATE INDEX idx_product_item_brand ON product_item(brand_id);
CREATE INDEX idx_product_item_category ON product_item(category_id); 
CREATE INDEX idx_product_item_active ON product_item(is_active);
CREATE INDEX idx_product_item_featured ON product_item(is_featured);
CREATE INDEX idx_product_item_stock ON product_item(stock_status);
    
    -- Constraints
    CONSTRAINT fk_brand FOREIGN KEY (brand_id) 
        REFERENCES brand(brand_id) ON DELETE RESTRICT,
    CONSTRAINT fk_category FOREIGN KEY (category_id) 
        REFERENCES product_category(category_id) ON DELETE RESTRICT,
    CONSTRAINT uq_product_sku UNIQUE (sku),
    CONSTRAINT uq_product_url_slug UNIQUE (url_slug),
    CONSTRAINT chk_stock_status CHECK (stock_status IN ('in_stock', 'out_of_stock', 'backorder', 'discontinued', 'coming_soon')),
    CONSTRAINT chk_rating CHECK (average_rating BETWEEN 0 AND 5 OR average_rating IS NULL)
);

-- Indexes for common lookups
CREATE INDEX idx_product_item_brand ON product_item(brand_id);
CREATE INDEX idx_product_item_category ON product_item(category_id); 
CREATE INDEX idx_product_item_active ON product_item(is_active);
CREATE INDEX idx_product_item_featured ON product_item(is_featured) WHERE is_featured = TRUE;
CREATE INDEX idx_product_item_stock ON product_item(stock_status);

-- Full-text search index
CREATE INDEX idx_product_item_fts ON product_item 
USING gin((to_tsvector('english', product_name) || 
           to_tsvector('english', COALESCE(product_description, '')) ||
           to_tsvector('english', array_to_string(COALESCE(search_keywords, ARRAY[]::text[]), ' '))));

-- Function for updating timestamp
CREATE OR REPLACE FUNCTION update_product_item_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update timestamp
CREATE TRIGGER trg_product_item_timestamp
BEFORE UPDATE ON product_item
FOR EACH ROW
EXECUTE FUNCTION update_product_item_timestamp();

-- Function to format URL slugs
CREATE OR REPLACE FUNCTION format_product_slug()
RETURNS TRIGGER AS $$
BEGIN
    -- Replace spaces with hyphens, remove special characters, convert to lowercase
    NEW.url_slug = LOWER(REGEXP_REPLACE(REGEXP_REPLACE(NEW.product_name, '[^a-zA-Z0-9\s]', '', 'g'), '\s+', '-', 'g'));
    
    -- Append SKU to ensure uniqueness if needed
    IF EXISTS (SELECT 1 FROM product_item WHERE url_slug = NEW.url_slug AND product_item_id != COALESCE(NEW.product_item_id, -1)) THEN
        NEW.url_slug = NEW.url_slug || '-' || NEW.sku;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-format URL slugs on insert if not provided
CREATE TRIGGER trg_format_product_slug
BEFORE INSERT ON product_item
FOR EACH ROW
WHEN (NEW.url_slug IS NULL OR NEW.url_slug = '')
EXECUTE FUNCTION format_product_slug();


-- product table

CREATE TABLE product (
    product_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    product_sku VARCHAR(50) NOT NULL,
    product_name VARCHAR(255) NOT NULL,
    product_slug VARCHAR(255) NOT NULL,
    short_description VARCHAR(500) DEFAULT NULL,
    long_description TEXT DEFAULT NULL,
    brand_id INT NOT NULL,
    primary_category_id INT NOT NULL,
    tax_class_id INT DEFAULT NULL,
    base_cost DECIMAL(12,4) NOT NULL,
    base_price DECIMAL(12,4) NOT NULL,
    msrp DECIMAL(12,4) DEFAULT NULL,
    map_price DECIMAL(12,4) DEFAULT NULL,
    clearance_price DECIMAL(12,4) DEFAULT NULL,
    price_tier_id INT DEFAULT NULL,
    has_variants BOOLEAN DEFAULT FALSE,
    manage_inventory BOOLEAN DEFAULT TRUE,
    min_order_quantity INT DEFAULT 1,
    max_order_quantity INT DEFAULT NULL,
    reorder_point INT DEFAULT NULL,
    reorder_quantity INT DEFAULT NULL,
    lead_time_days INT DEFAULT NULL,
    weight DECIMAL(10,4) DEFAULT NULL,
    length DECIMAL(10,4) DEFAULT NULL,
    width DECIMAL(10,4) DEFAULT NULL,
    height DECIMAL(10,4) DEFAULT NULL,
    dimension_unit ENUM('cm', 'in', 'm') DEFAULT 'cm',
    weight_unit ENUM('kg', 'g', 'lb', 'oz') DEFAULT 'kg',
    is_shippable BOOLEAN DEFAULT TRUE,
    free_shipping BOOLEAN DEFAULT FALSE,
    shipping_class_id INT DEFAULT NULL,
    additional_shipping_fee DECIMAL(10,4) DEFAULT 0.00,
    is_digital BOOLEAN DEFAULT FALSE,
    digital_file_path VARCHAR(500) DEFAULT NULL,
    download_limit INT DEFAULT NULL,
    download_expiry_days INT DEFAULT NULL,
    status ENUM('draft', 'active', 'inactive', 'discontinued', 'archived') DEFAULT 'draft',
    visibility ENUM('visible', 'catalog', 'search', 'hidden') DEFAULT 'visible',
    is_featured BOOLEAN DEFAULT FALSE,
    searchable BOOLEAN DEFAULT TRUE,
    listed_on_marketplace BOOLEAN DEFAULT TRUE,
    meta_title VARCHAR(255) DEFAULT NULL,
    meta_description VARCHAR(500) DEFAULT NULL,
    meta_keywords VARCHAR(255) DEFAULT NULL,
    primary_image_id BIGINT DEFAULT NULL,
    video_url VARCHAR(255) DEFAULT NULL,
    primary_supplier_id INT DEFAULT NULL,
    secondary_supplier_id INT DEFAULT NULL,
    manufacturer_id INT DEFAULT NULL,
    manufacturer_part_number VARCHAR(100) DEFAULT NULL,
    country_of_origin VARCHAR(2) DEFAULT NULL,
    warranty_months INT DEFAULT NULL,
    return_policy_id INT DEFAULT NULL,
    quality_control_required BOOLEAN DEFAULT FALSE,
    serialized BOOLEAN DEFAULT FALSE,
    batch_tracked BOOLEAN DEFAULT FALSE,
    expiry_tracked BOOLEAN DEFAULT FALSE,
    barcode_upc VARCHAR(20) DEFAULT NULL,
    barcode_ean VARCHAR(20) DEFAULT NULL,
    barcode_isbn VARCHAR(20) DEFAULT NULL,
    approved_by INT DEFAULT NULL,
    approval_date DATETIME DEFAULT NULL,
    safety_stock INT DEFAULT 0,
    certification_ids JSON DEFAULT NULL,
    restricted_in_countries JSON DEFAULT NULL,
    hazmat_class VARCHAR(50) DEFAULT NULL,
    related_products JSON DEFAULT NULL,
    upsell_products JSON DEFAULT NULL,
    cross_sell_products JSON DEFAULT NULL,
    internal_notes TEXT DEFAULT NULL,
    procurement_notes TEXT DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    published_at DATETIME DEFAULT NULL,
    deleted_at DATETIME DEFAULT NULL,
    created_by INT NOT NULL,
    updated_by INT DEFAULT NULL,
    UNIQUE INDEX idx_product_sku (product_sku),
    UNIQUE INDEX idx_product_slug (product_slug),
    INDEX idx_product_name (product_name),
    INDEX idx_brand_id (brand_id),
    INDEX idx_primary_category_id (primary_category_id),
    INDEX idx_status (status),
    INDEX idx_visibility (visibility),
    INDEX idx_is_featured (is_featured),
    INDEX idx_created_at (created_at),
    INDEX idx_published_at (published_at),
    FOREIGN KEY (brand_id) REFERENCES brand(brand_id) ON DELETE RESTRICT,
    FOREIGN KEY (primary_category_id) REFERENCES product_category(category_id) ON DELETE RESTRICT,
    FOREIGN KEY (primary_supplier_id) REFERENCES supplier(supplier_id) ON DELETE SET NULL,
    FOREIGN KEY (tax_class_id) REFERENCES tax_class(tax_class_id) ON DELETE SET NULL,
    FOREIGN KEY (shipping_class_id) REFERENCES shipping_class(shipping_class_id) ON DELETE SET NULL,
    FOREIGN KEY (return_policy_id) REFERENCES return_policy(return_policy_id) ON DELETE SET NULL,
    FOREIGN KEY (primary_image_id) REFERENCES product_image(image_id) ON DELETE SET NULL,
    FOREIGN KEY (created_by) REFERENCES admin_user(admin_id) ON DELETE RESTRICT,
    FOREIGN KEY (updated_by) REFERENCES admin_user(admin_id) ON DELETE SET NULL
);
    
    -- Classification
    brand_id INT NOT NULL,
    primary_category_id INT NOT NULL,
    tax_class_id INT DEFAULT NULL,
    
    -- Pricing
    base_cost DECIMAL(12, 4) NOT NULL COMMENT 'Supplier cost',
    base_price DECIMAL(12, 4) NOT NULL COMMENT 'Standard retail price',
    msrp DECIMAL(12, 4) DEFAULT NULL COMMENT 'Manufacturer suggested retail price',
    map_price DECIMAL(12, 4) DEFAULT NULL COMMENT 'Minimum advertised price',
    clearance_price DECIMAL(12, 4) DEFAULT NULL,
    price_tier_id INT DEFAULT NULL COMMENT 'For tiered pricing structures',
    
    -- Inventory
    has_variants BOOLEAN DEFAULT FALSE COMMENT 'True if this product has multiple variants',
    manage_inventory BOOLEAN DEFAULT TRUE COMMENT 'Whether to track inventory for this product',
    min_order_quantity INT DEFAULT 1,
    max_order_quantity INT DEFAULT NULL,
    reorder_point INT DEFAULT NULL COMMENT 'Inventory level that triggers reorder',
    reorder_quantity INT DEFAULT NULL COMMENT 'Suggested quantity to reorder',
    lead_time_days INT DEFAULT NULL COMMENT 'Typical days for restock',
    
    -- Physical attributes
    weight DECIMAL(10, 4) DEFAULT NULL COMMENT 'In kg',
    length DECIMAL(10, 4) DEFAULT NULL COMMENT 'In cm',
    width DECIMAL(10, 4) DEFAULT NULL COMMENT 'In cm',
    height DECIMAL(10, 4) DEFAULT NULL COMMENT 'In cm',
    dimension_unit ENUM('cm', 'in', 'm') DEFAULT 'cm',
    weight_unit ENUM('kg', 'g', 'lb', 'oz') DEFAULT 'kg',
    
    -- Shipping attributes
    is_shippable BOOLEAN DEFAULT TRUE,
    free_shipping BOOLEAN DEFAULT FALSE,
    shipping_class_id INT DEFAULT NULL,
    additional_shipping_fee DECIMAL(10, 4) DEFAULT 0.00,
    
    -- Digital product attributes
    is_digital BOOLEAN DEFAULT FALSE,
    digital_file_path VARCHAR(500) DEFAULT NULL,
    download_limit INT DEFAULT NULL,
    download_expiry_days INT DEFAULT NULL,
    
    -- Visibility & Status
    status ENUM('draft', 'active', 'inactive', 'discontinued', 'archived') DEFAULT 'draft',
    visibility ENUM('visible', 'catalog', 'search', 'hidden') DEFAULT 'visible' COMMENT 'Where product appears',
    is_featured BOOLEAN DEFAULT FALSE,
    searchable BOOLEAN DEFAULT TRUE,
    listed_on_marketplace BOOLEAN DEFAULT TRUE,
    
    -- SEO attributes
    meta_title VARCHAR(255) DEFAULT NULL,
    meta_description VARCHAR(500) DEFAULT NULL,
    meta_keywords VARCHAR(255) DEFAULT NULL,
    
    -- Media
    primary_image_id BIGINT DEFAULT NULL,
    video_url VARCHAR(255) DEFAULT NULL,
    
    -- Supply chain
    primary_supplier_id INT DEFAULT NULL,
    secondary_supplier_id INT DEFAULT NULL,
    manufacturer_id INT DEFAULT NULL,
    manufacturer_part_number VARCHAR(100) DEFAULT NULL,
    country_of_origin VARCHAR(2) DEFAULT NULL COMMENT 'ISO country code',
    
    -- Misc attributes
    warranty_months INT DEFAULT NULL,
    return_policy_id INT DEFAULT NULL,
    quality_control_required BOOLEAN DEFAULT FALSE,
    serialized BOOLEAN DEFAULT FALSE COMMENT 'True if each unit has a unique serial number',
    batch_tracked BOOLEAN DEFAULT FALSE COMMENT 'True if product is tracked by batch/lot',
    expiry_tracked BOOLEAN DEFAULT FALSE COMMENT 'True if product has expiry dates',
    barcode_upc VARCHAR(20) DEFAULT NULL COMMENT 'Universal Product Code',
    barcode_ean VARCHAR(20) DEFAULT NULL COMMENT 'European Article Number',
    barcode_isbn VARCHAR(20) DEFAULT NULL COMMENT 'For books',
    
    -- Approval & compliance
    approved_by INT DEFAULT NULL COMMENT 'User ID of approver',
    approval_date DATETIME DEFAULT NULL,
    safety_stock INT DEFAULT 0 COMMENT 'Minimum quantity to keep in stock',
    certification_ids JSON DEFAULT NULL COMMENT 'IDs of certifications (CE, RoHS, etc.)',
    restricted_in_countries JSON DEFAULT NULL COMMENT 'Countries where product cannot be sold',
    hazmat_class VARCHAR(50) DEFAULT NULL COMMENT 'Hazardous material classification',
    
    -- Cross-selling and recommendations
    related_products JSON DEFAULT NULL COMMENT 'Product IDs for related products',
    upsell_products JSON DEFAULT NULL COMMENT 'Product IDs for upsell products',
    cross_sell_products JSON DEFAULT NULL COMMENT 'Product IDs for cross-sell products',
    
    -- Internal administration
    internal_notes TEXT DEFAULT NULL,
    procurement_notes TEXT DEFAULT NULL,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    published_at DATETIME DEFAULT NULL,
    deleted_at DATETIME DEFAULT NULL COMMENT 'For soft deletes',
    
    -- User tracking
    created_by INT NOT NULL COMMENT 'User ID of creator',
    updated_by INT DEFAULT NULL COMMENT 'User ID of last editor',
    
    -- Indices
    UNIQUE INDEX idx_product_sku (product_sku),
    UNIQUE INDEX idx_product_slug (product_slug),
    INDEX idx_product_name (product_name),
    INDEX idx_brand_id (brand_id),
    INDEX idx_primary_category_id (primary_category_id),
    INDEX idx_status (status),
    INDEX idx_visibility (visibility),
    INDEX idx_is_featured (is_featured),
    INDEX idx_created_at (created_at),
    INDEX idx_published_at (published_at),
) 


-- brand table

CREATE TABLE brand (
    brand_id INT AUTO_INCREMENT PRIMARY KEY,
    brand_name VARCHAR(100) NOT NULL,
    brand_description TEXT,
    logo_url VARCHAR(500),
    website_url VARCHAR(255),
    founded_year SMALLINT,
    country_of_origin VARCHAR(100),
    url_slug VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    featured_priority SMALLINT DEFAULT 0,
    brand_color VARCHAR(7),
    meta_title VARCHAR(255),
    meta_description VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT uq_brand_name UNIQUE (brand_name),
    CONSTRAINT uq_brand_slug UNIQUE (url_slug),
    CONSTRAINT chk_founded_year CHECK (founded_year >= 1000 AND founded_year <= YEAR(CURDATE())),
    CONSTRAINT chk_color_format CHECK (brand_color REGEXP '^#[0-9A-Fa-f]{6}$' OR brand_color IS NULL)
);

CREATE INDEX idx_brand_slug ON brand(url_slug);
CREATE INDEX idx_brand_featured ON brand(featured_priority);

-- Function for updating timestamp
CREATE OR REPLACE FUNCTION update_brand_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update timestamp
CREATE TRIGGER trg_brand_timestamp
BEFORE UPDATE ON brand
FOR EACH ROW
EXECUTE FUNCTION update_brand_timestamp();

-- Function to format URL slugs
CREATE OR REPLACE FUNCTION format_brand_slug()
RETURNS TRIGGER AS $$
BEGIN
    -- Replace spaces with hyphens, remove special characters, convert to lowercase
    NEW.url_slug = LOWER(REGEXP_REPLACE(REGEXP_REPLACE(NEW.brand_name, '[^a-zA-Z0-9\s]', '', 'g'), '\s+', '-', 'g'));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-format URL slugs on insert if not provided
CREATE TRIGGER trg_format_brand_slug
BEFORE INSERT ON brand
FOR EACH ROW
WHEN (NEW.url_slug IS NULL OR NEW.url_slug = '')
EXECUTE FUNCTION format_brand_slug();

-- Function to get brand statistics
CREATE OR REPLACE FUNCTION get_brand_statistics(p_brand_id INTEGER)
RETURNS TABLE (
    total_products INTEGER,
    active_products INTEGER,
    product_categories INTEGER,
    avg_price DECIMAL(15, 2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(DISTINCT pi.product_item_id) AS total_products,
        COUNT(DISTINCT pi.product_item_id) FILTER (WHERE pi.is_active = TRUE) AS active_products,
        COUNT(DISTINCT pi.category_id) AS product_categories,
        AVG(pi.base_price) AS avg_price
    FROM product_item pi
    WHERE pi.brand_id = p_brand_id;
END;
$$ LANGUAGE plpgsql;


-- product_variation

CREATE TABLE product_variation (
    variation_id SERIAL PRIMARY KEY,
    product_item_id INTEGER NOT NULL,
    size_option_id INTEGER,
    color_code VARCHAR(7),
    color_name VARCHAR(50),
    variation_sku VARCHAR(50) NOT NULL,
    additional_price DECIMAL(10, 2) DEFAULT 0.00,
    stock_quantity INTEGER NOT NULL DEFAULT 0,
    low_stock_threshold INTEGER DEFAULT 5,
    weight_diff_kg DECIMAL(10, 3) DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    image_url VARCHAR(500),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    custom_attributes JSONB,
    barcode VARCHAR(50),
    location_code VARCHAR(50),
    
    -- Constraints
    CONSTRAINT fk_product_item FOREIGN KEY (product_item_id) 
        REFERENCES product_item(product_item_id) ON DELETE CASCADE,
    CONSTRAINT fk_size_option FOREIGN KEY (size_option_id) 
        REFERENCES size_option(size_option_id) ON DELETE RESTRICT,
    CONSTRAINT uq_variation_sku UNIQUE (variation_sku),
    CONSTRAINT chk_color_format CHECK (color_code ~ '^#[0-9A-Fa-f]{6}$' OR color_code IS NULL)
);

-- Indexes for common queries
CREATE INDEX idx_product_variation_item ON product_variation(product_item_id);
CREATE INDEX idx_product_variation_size ON product_variation(size_option_id);
CREATE INDEX idx_product_variation_stock ON product_variation(stock_quantity) WHERE stock_quantity > 0;

-- Composite index for common filtering
CREATE INDEX idx_product_variation_filter ON product_variation(product_item_id, is_active, stock_quantity);

-- Function for updating timestamp
CREATE OR REPLACE FUNCTION update_product_variation_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update timestamp
CREATE TRIGGER trg_product_variation_timestamp
BEFORE UPDATE ON product_variation
FOR EACH ROW
EXECUTE FUNCTION update_product_variation_timestamp();

-- Stock audit log table
CREATE TABLE product_variation_stock_log (
    log_id SERIAL PRIMARY KEY,
    variation_id INTEGER NOT NULL,
    previous_quantity INTEGER NOT NULL,
    new_quantity INTEGER NOT NULL,
    change_amount INTEGER NOT NULL,
    change_type VARCHAR(20) NOT NULL,
    reference_id VARCHAR(50),
    notes TEXT,
    changed_by VARCHAR(100),
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_product_variation FOREIGN KEY (variation_id)
        REFERENCES product_variation(variation_id) ON DELETE CASCADE,
    CONSTRAINT chk_change_type CHECK (change_type IN ('purchase', 'sale', 'return', 'adjustment', 'inventory', 'damaged', 'lost'))
);

-- Function to log stock changes
CREATE OR REPLACE FUNCTION log_stock_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.stock_quantity != NEW.stock_quantity THEN
        INSERT INTO product_variation_stock_log (
            variation_id, 
            previous_quantity, 
            new_quantity, 
            change_amount,
            change_type,
            changed_by
        ) VALUES (
            NEW.variation_id,
            OLD.stock_quantity,
            NEW.stock_quantity,
            NEW.stock_quantity - OLD.stock_quantity,
            'adjustment', -- Default type, can be updated later
            current_user
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to log stock changes
CREATE TRIGGER trg_log_stock_change
AFTER UPDATE OF stock_quantity ON product_variation
FOR EACH ROW
EXECUTE FUNCTION log_stock_change();

-- Function to get low stock variations
CREATE OR REPLACE FUNCTION get_low_stock_variations()
RETURNS TABLE (
    variation_id INTEGER,
    product_name VARCHAR(255),
    variation_sku VARCHAR(50),
    current_stock INTEGER,
    threshold INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pv.variation_id,
        pi.product_name,
        pv.variation_sku,
        pv.stock_quantity,
        pv.low_stock_threshold
    FROM product_variation pv
    JOIN product_item pi ON pv.product_item_id = pi.product_item_id
    WHERE pv.is_active = TRUE
    AND pv.stock_quantity <= pv.low_stock_threshold
    ORDER BY pv.stock_quantity ASC;
END;
$$ LANGUAGE plpgsql;


-- size_category table

CREATE TABLE size_category (
    size_category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(50) NOT NULL,
    display_order INTEGER DEFAULT 0,
    size_guide_url VARCHAR(500),
    measurement_unit VARCHAR(20) DEFAULT 'cm',
    is_active BOOLEAN DEFAULT TRUE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT uq_size_category_name UNIQUE (category_name),
    CONSTRAINT chk_measurement_unit CHECK (measurement_unit IN ('cm', 'inches', 'mm', 'feet', 'meters', 'us', 'eu', 'uk', 'international'))
);

-- Function for updating timestamp
CREATE OR REPLACE FUNCTION update_size_category_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update timestamp
CREATE TRIGGER trg_size_category_timestamp
BEFORE UPDATE ON size_category
FOR EACH ROW
EXECUTE FUNCTION update_size_category_timestamp();

-- Insert common size categories
INSERT INTO size_category (category_name, display_order, measurement_unit) VALUES
('Clothing', 10, 'international'),
('Shoes', 20, 'eu'),
('Hats', 30, 'cm'),
('Gloves', 40, 'cm'),
('Children''s Clothing', 50, 'cm'),
('Children''s Shoes', 60, 'eu'),
('Accessories', 70, 'cm'),
('Electronics', 80, 'inches');


-- size_option

CREATE TABLE size_option (
    size_option_id SERIAL PRIMARY KEY,
    size_category_id INTEGER NOT NULL,
    size_name VARCHAR(50) NOT NULL,
    size_code VARCHAR(20) NOT NULL,
    display_order INTEGER DEFAULT 0,
    dimensions JSONB,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Cross reference for size equivalence
    equivalent_sizes JSONB,
    
    -- Constraints
    CONSTRAINT fk_size_category FOREIGN KEY (size_category_id) 
        REFERENCES size_category(size_category_id) ON DELETE RESTRICT,
    CONSTRAINT uq_size_category_code UNIQUE (size_category_id, size_code)
);

-- Indexes for faster lookups
CREATE INDEX idx_size_option_category ON size_option(size_category_id);
CREATE INDEX idx_size_option_active ON size_option(is_active);

-- Function for updating timestamp
CREATE OR REPLACE FUNCTION update_size_option_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update timestamp
CREATE TRIGGER trg_size_option_timestamp
BEFORE UPDATE ON size_option
FOR EACH ROW
EXECUTE FUNCTION update_size_option_timestamp();

-- Insert sample clothing sizes
INSERT INTO size_option (size_category_id, size_name, size_code, display_order, dimensions, equivalent_sizes) 
SELECT 
    1, -- Clothing category
    size_name,
    size_code,
    display_order,
    dimensions,
    equivalent_sizes
FROM (VALUES
    ('Extra Small', 'XS', 10, '{"chest": 86, "waist": 71, "hips": 89}', '{"us": "XS", "uk": "XS", "eu": "XS"}'),
    ('Small', 'S', 20, '{"chest": 91, "waist": 76, "hips": 94}', '{"us": "S", "uk": "S", "eu": "S"}'),
    ('Medium', 'M', 30, '{"chest": 97, "waist": 81, "hips": 99}', '{"us": "M", "uk": "M", "eu": "M"}'),
    ('Large', 'L', 40, '{"chest": 104, "waist": 86, "hips": 104}', '{"us": "L", "uk": "L", "eu": "L"}'),
    ('Extra Large', 'XL', 50, '{"chest": 111, "waist": 94, "hips": 109}', '{"us": "XL", "uk": "XL", "eu": "XL"}'),
    ('XXL', 'XXL', 60, '{"chest": 119, "waist": 102, "hips": 117}', '{"us": "XXL", "uk": "XXL", "eu": "XXL"}')
) AS data(size_name, size_code, display_order, dimensions, equivalent_sizes);

-- Insert sample shoe sizes
INSERT INTO size_option (size_category_id, size_name, size_code, display_order, dimensions, equivalent_sizes) 
SELECT 
    2, -- Shoes category
    size_name,
    size_code,
    display_order,
    dimensions,
    equivalent_sizes
FROM (VALUES
    ('EU 37', '37', 10, '{"length": 23.5}', '{"us": "6", "uk": "4", "cm": "23.5"}'),
    ('EU 38', '38', 20, '{"length": 24.0}', '{"us": "7", "uk": "5", "cm": "24.0"}'),
    ('EU 39', '39', 30, '{"length": 24.5}', '{"us": "7.5", "uk": "5.5", "cm": "24.5"}'),
    ('EU 40', '40', 40, '{"length": 25.0}', '{"us": "8", "uk": "6", "cm": "25.0"}'),
    ('EU 41', '41', 50, '{"length": 26.0}', '{"us": "9", "uk": "7", "cm": "26.0"}'),
    ('EU 42', '42', 60, '{"length": 26.5}', '{"us": "9.5", "uk": "7.5", "cm": "26.5"}'),
    ('EU 43', '43', 70, '{"length": 27.0}', '{"us": "10", "uk": "8", "cm": "27.0"}'),
    ('EU 44', '44', 80, '{"length": 28.0}', '{"us": "11", "uk": "9", "cm": "28.0"}')
) AS data(size_name, size_code, display_order, dimensions, equivalent_sizes);

-- Function to get available sizes for a product
CREATE OR REPLACE FUNCTION get_product_available_sizes(p_product_item_id INTEGER)
RETURNS TABLE (
    size_option_id INTEGER,
    size_name VARCHAR(50),
    size_code VARCHAR(20),
    stock_quantity INTEGER,
    is_available BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        so.size_option_id,
        so.size_name,
        so.size_code,
        COALESCE(pv.stock_quantity, 0) AS stock_quantity,
        COALESCE(pv.stock_quantity > 0 AND pv.is_active, FALSE) AS is_available
    FROM size_option so
    LEFT JOIN product_variation pv ON so.size_option_id = pv.size_option_id AND pv.product_item_id = p_product_item_id
    WHERE so.is_active = TRUE
    ORDER BY so.display_order;
END;
$$ LANGUAGE plpgsql;


-- product_attribute table

CREATE TABLE product_attribute (
    attribute_id SERIAL PRIMARY KEY,
    product_item_id INTEGER NOT NULL,
    attribute_type_id INTEGER NOT NULL,
    attribute_value TEXT NOT NULL,
    display_order INTEGER DEFAULT 0,
    is_filterable BOOLEAN DEFAULT TRUE,
    is_visible BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- For numerical attributes
    value_numeric DECIMAL(15, 6),
    
    -- For date attributes
    value_date DATE,
    
    -- For boolean attributes
    value_boolean BOOLEAN,
    
    -- Constraints
    CONSTRAINT fk_product_item FOREIGN KEY (product_item_id) 
        REFERENCES product_item(product_item_id) ON DELETE CASCADE,
    CONSTRAINT fk_attribute_type FOREIGN KEY (attribute_type_id) 
        REFERENCES attribute_type(attribute_type_id) ON DELETE RESTRICT,
    CONSTRAINT uq_product_attribute UNIQUE (product_item_id, attribute_type_id)
);

-- Indexes for faster queries and filtering
CREATE INDEX idx_product_attribute_item ON product_attribute(product_item_id);
CREATE INDEX idx_product_attribute_type ON product_attribute(attribute_type_id);
CREATE INDEX idx_product_attribute_filterable ON product_attribute(attribute_type_id, is_filterable) WHERE is_filterable = TRUE;

-- Create index for each value type
CREATE INDEX idx_product_attribute_value_text ON product_attribute(attribute_value) WHERE attribute_value IS NOT NULL;
CREATE INDEX idx_product_attribute_value_numeric ON product_attribute(value_numeric) WHERE value_numeric IS NOT NULL;
CREATE INDEX idx_product_attribute_value_date ON product_attribute(value_date) WHERE value_date IS NOT NULL;
CREATE INDEX idx_product_attribute_value_boolean ON product_attribute(value_boolean) WHERE value_boolean IS NOT NULL;

-- Function for updating timestamp
CREATE OR REPLACE FUNCTION update_product_attribute_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update timestamp
CREATE TRIGGER trg_product_attribute_timestamp
BEFORE UPDATE ON product_attribute
FOR EACH ROW
EXECUTE FUNCTION update_product_attribute_timestamp();

-- Function to type-cast values based on attribute type
CREATE OR REPLACE FUNCTION cast_attribute_value()
RETURNS TRIGGER AS $$
DECLARE
    v_data_type VARCHAR(50);
BEGIN
    -- Get the data type for this attribute
    SELECT data_type INTO v_data_type
    FROM attribute_type
    WHERE attribute_type_id = NEW.attribute_type_id;
    
    -- Cast value to appropriate type
    CASE v_data_type
        WHEN 'numeric' THEN
            BEGIN
                NEW.value_numeric = NEW.attribute_value::DECIMAL(15,6);
            EXCEPTION WHEN OTHERS THEN
                NEW.value_numeric = NULL;
            END;
        WHEN 'date' THEN
            BEGIN
                NEW.value_date = NEW.attribute_value::DATE;
            EXCEPTION WHEN OTHERS THEN
                NEW.value_date = NULL;
            END;
        WHEN 'boolean' THEN
            BEGIN
                NEW.value_boolean = 
                    CASE LOWER(NEW.attribute_value)
                        WHEN 'true' THEN TRUE
                        WHEN 'yes' THEN TRUE
                        WHEN '1' THEN TRUE
                        WHEN 'false' THEN FALSE
                        WHEN 'no' THEN FALSE
                        WHEN '0' THEN FALSE
                        ELSE NULL
                    END;
            EXCEPTION WHEN OTHERS THEN
                NEW.value_boolean = NULL;
            END;
        ELSE
            -- Text type, no casting needed
            NULL;
    END CASE;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- attribute_category table

CREATE TABLE attribute_category (
    category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL,
    category_description TEXT,
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    icon_class VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT uq_attribute_category_name UNIQUE (category_name)
);

-- Index for active categories
CREATE INDEX idx_attribute_category_active ON attribute_category(is_active);

-- Function for updating timestamp
CREATE OR REPLACE FUNCTION update_attribute_category_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update timestamp
CREATE TRIGGER trg_attribute_category_timestamp
BEFORE UPDATE ON attribute_category
FOR EACH ROW
EXECUTE FUNCTION update_attribute_category_timestamp();

-- Insert common attribute categories
INSERT INTO attribute_category (category_name, category_description, display_order) VALUES
('Technical', 'Technical specifications and features', 10),
('Physical', 'Physical characteristics and dimensions', 20),
('Material', 'Material composition and details', 30),
('Performance', 'Performance metrics and ratings', 40),
('Environmental', 'Environmental certifications and properties', 50),
('Care', 'Care instructions and maintenance', 60),
('Warranty', 'Warranty information and support', 70),
('Compatibility', 'Compatibility with other products or systems', 80);

-- Function to get attribute categories with attributes count
CREATE OR REPLACE FUNCTION get_attribute_categories_with_count()
RETURNS TABLE (
    category_id INTEGER,
    category_name VARCHAR(100),
    category_description TEXT,
    attributes_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ac.category_id,
        ac.category_name,
        ac.category_description,
        COUNT(at.attribute_type_id) AS attributes_count
    FROM attribute_category ac
    LEFT JOIN attribute_type at ON ac.category_id = at.category_id
    WHERE ac.is_active = TRUE
    GROUP BY ac.category_id, ac.category_name, ac.category_description
    ORDER BY ac.display_order, ac.category_name;
END;
$$ LANGUAGE plpgsql;


-- attribute_type table

CREATE TABLE attribute_type (
    attribute_type_id SERIAL PRIMARY KEY,
    category_id INTEGER NOT NULL,
    attribute_name VARCHAR(100) NOT NULL,
    attribute_description TEXT,
    data_type VARCHAR(50) DEFAULT 'text',
    is_required BOOLEAN DEFAULT FALSE,
    is_filterable BOOLEAN DEFAULT TRUE,
    is_comparable BOOLEAN DEFAULT TRUE,
    display_order INTEGER DEFAULT 0,
    default_value TEXT,
    validation_regex VARCHAR(500),
    unit_of_measure VARCHAR(50),
    allowed_values TEXT[],
    search_weight SMALLINT DEFAULT 1,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT fk_attribute_category FOREIGN KEY (category_id) 
        REFERENCES attribute_category(category_id) ON DELETE RESTRICT,
    CONSTRAINT uq_attribute_type_name UNIQUE (attribute_name),
    CONSTRAINT chk_data_type CHECK (data_type IN ('text', 'numeric', 'boolean', 'date', 'select', 'multiselect')),
    CONSTRAINT chk_search_weight CHECK (search_weight BETWEEN 0 AND 10)
);

-- Indexes for faster queries
CREATE INDEX idx_attribute_type_category ON attribute_type(category_id);
CREATE INDEX idx_attribute_type_filterable ON attribute_type(is_filterable) WHERE is_filterable = TRUE;
CREATE INDEX idx_attribute_type_comparable ON attribute_type(is_comparable) WHERE is_comparable = TRUE;
CREATE INDEX idx_attribute_type_active ON attribute_type(is_active);

-- Function for updating timestamp
CREATE OR REPLACE FUNCTION update_attribute_type_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update timestamp
CREATE TRIGGER trg_attribute_type_timestamp
BEFORE UPDATE ON attribute_type
FOR EACH ROW
EXECUTE FUNCTION update_attribute_type_timestamp();

-- Function to validate attribute values against type rules
CREATE OR REPLACE FUNCTION validate_attribute_value(
    p_attribute_type_id INTEGER,
    p_value TEXT
) RETURNS BOOLEAN AS $$
DECLARE
    v_data_type VARCHAR(50);
    v_validation_regex VARCHAR(500);
    v_allowed_values TEXT[];
    v_is_valid BOOLEAN := TRUE;
BEGIN
    -- Get attribute type details
    SELECT 
        data_type,
        validation_regex,
        allowed_values
    INTO 
        v_data_type,
        v_validation_regex,
        v_allowed_values
    FROM attribute_type
    WHERE attribute_type_id = p_attribute_type_id;
    
    -- Check data type
    CASE v_data_type
        WHEN 'numeric' THEN
            -- Validate as number
            BEGIN
                PERFORM p_value::DECIMAL;
            EXCEPTION WHEN OTHERS THEN
                v_is_valid := FALSE;
            END;
        WHEN 'date' THEN
            -- Validate as date
            BEGIN
                PERFORM p_value::DATE;
            EXCEPTION WHEN OTHERS THEN
                v_is_valid := FALSE;
            END;
        WHEN 'boolean' THEN
            -- Validate as boolean
            IF p_value NOT IN ('true', 'false', 'yes', 'no', '1', '0') THEN
                v_is_valid := FALSE;
            END IF;
        WHEN 'select' THEN
            -- Validate from allowed values
            IF v_allowed_values IS NOT NULL AND p_value IS NOT NULL THEN
                IF NOT p_value = ANY(v_allowed_values) THEN
                    v_is_valid := FALSE;
                END IF;
            END IF;
        WHEN 'multiselect' THEN
            -- Validate multiple values from allowed values
            IF v_allowed_values IS NOT NULL THEN
                DECLARE
                    v_value_array TEXT[];
                    v_value TEXT;
                BEGIN
                    -- Split input value by comma
                    v_value_array := string_to_array(p_value, ',');
                    
                    -- Check each value
                    FOREACH v_value IN ARRAY v_value_array LOOP
                        IF NOT v_value = ANY(v_allowed_values) THEN
                            v_is_valid := FALSE;
                            EXIT;
                        END IF;
                    END LOOP;
                END;
            END IF;
        ELSE
            -- Text type, always valid
            NULL;
    END CASE;
    
    -- Check regex if provided
    IF v_is_valid AND v_validation_regex IS NOT NULL AND p_value IS NOT NULL THEN
        IF NOT p_value ~ v_validation_regex THEN
            v_is_valid := FALSE;
        END IF;
    END IF;
    
    RETURN v_is_valid;
END;
$$ LANGUAGE plpgsql;

-- Insert common attribute types
INSERT INTO attribute_type (
    category_id, attribute_name, attribute_description, 
    data_type, is_required, is_filterable, is_comparable, 
    unit_of_measure, allowed_values
) VALUES
-- Technical attributes
(1, 'Operating System', 'Operating system or platform', 'select', false, true, true, null, 
    ARRAY['Android', 'iOS', 'Windows', 'macOS', 'Linux', 'ChromeOS']),
(1, 'Processor', 'CPU or processor details', 'text', false, true, true, null, null),
(1, 'Memory (RAM)', 'Random access memory capacity', 'numeric', false, true, true, 'GB', null),
(1, 'Storage Capacity', 'Storage size or capacity', 'numeric', false, true, true, 'GB', null),
(1, 'Screen Size', 'Display diagonal size', 'numeric', false, true, true, 'inches', null),
(1, 'Resolution', 'Screen or image resolution', 'text', false, true, true, 'pixels', null),
(1, 'Connectivity', 'Available connectivity options', 'multiselect', false, true, false, null, 
    ARRAY['WiFi', 'Bluetooth', 'USB-C', 'Lightning', 'HDMI', 'Ethernet', '5G', '4G/LTE', 'NFC']),

-- Physical attributes
(2, 'Color', 'Product color', 'text', false, true, false, null, null),
(2, 'Material', 'Main material', 'multiselect', false, true, false, null, 
    ARRAY['Cotton', 'Polyester', 'Wool', 'Silk', 'Leather', 'Aluminum', 'Steel', 'Glass', 'Plastic']),
(2, 'Weight', 'Product weight', 'numeric', false, true, true, 'kg', null),
(2, 'Dimensions', 'Product dimensions (L × W × H)', 'text', false, false, false, null, null),

-- Material attributes
(3, 'Main Material', 'Primary material used', 'text', false, true, false, null, null),
(3, 'Material Composition', 'Breakdown of material components', 'text', false, false, false, 'percentage', null),
(3, 'Fabric Weight', 'Weight of the fabric', 'numeric', false, true, true, 'g/m²', null),

-- Performance attributes
(4, 'Battery Life', 'Estimated battery duration', 'numeric', false, true, true, 'hours', null),
(4, 'Water Resistance', 'Water resistance rating', 'text', false, true, false, null, null),
(4, 'Durability Rating', 'Product durability score', 'numeric', false, true, true, null, null),

-- Environmental attributes
(5, 'Eco-Friendly', 'Environmentally friendly product', 'boolean', false, true, false, null, null),
(5, 'Energy Efficiency', 'Energy efficiency rating', 'text', false, true, true, null, 
    ARRAY['A+++', 'A++', 'A+', 'A', 'B', 'C', 'D', 'E', 'F', 'G']),
(5, 'Recycled Content', 'Percentage of recycled materials', 'numeric', false, true, true, '%', null),

-- Care attributes
(6, 'Washing Instructions', 'How to wash the product', 'multiselect', false, false, false, null, 
    ARRAY['Machine wash cold', 'Machine wash warm', 'Hand wash only', 'Dry clean only', 'Do not wash']),
(6, 'Drying Instructions', 'How to dry the product', 'select', false, false, false, null, 
    ARRAY['Tumble dry low', 'Tumble dry medium', 'Tumble dry high', 'Air dry', 'Do not tumble dry']),

-- Warranty attributes
(7, 'Warranty Period', 'Duration of the warranty', 'numeric', false, true, true, 'months', null),
(7, 'Warranty Type', 'Type of warranty coverage', 'select', false, true, false, null, 
    ARRAY['Limited', 'Lifetime', 'Extended', 'Parts only', 'Labor only', 'Parts and labor']),

-- Compatibility attributes
(8, 'Compatible With', 'Compatible devices or systems', 'multiselect', false, true, false, null, null),
(8, 'Required Accessories', 'Accessories needed for full functionality', 'text', false, false, false, null, null);

-- Function to get attribute types by category
CREATE OR REPLACE FUNCTION get_attribute_types_by_category(p_category_id INTEGER)
RETURNS TABLE (
    attribute_type_id INTEGER,
    attribute_name VARCHAR(100),
    data_type VARCHAR(50),
    is_required BOOLEAN,
    unit_of_measure VARCHAR(50),
    allowed_values TEXT[]
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        at.attribute_type_id,
        at.attribute_name,
        at.data_type,
        at.is_required,
        at.unit_of_measure,
        at.allowed_values
    FROM attribute_type at
    WHERE at.category_id = p_category_id
    AND at.is_active = TRUE
    ORDER BY at.display_order, at.attribute_name;
END;
$$ LANGUAGE plpgsql;

-- Function to get product attributes formatted for display
CREATE OR REPLACE FUNCTION get_formatted_product_attributes(p_product_item_id INTEGER)
RETURNS TABLE (
    category_name VARCHAR(100),
    attribute_name VARCHAR(100),
    attribute_value TEXT,
    unit_of_measure VARCHAR(50)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ac.category_name,
        at.attribute_name,
        pa.attribute_value,
        at.unit_of_measure
    FROM product_attribute pa
    JOIN attribute_type at ON pa.attribute_type_id = at.attribute_type_id
    JOIN attribute_category ac ON at.category_id = ac.category_id
    WHERE pa.product_item_id = p_product_item_id
    AND pa.is_visible = TRUE
    AND at.is_active = TRUE
    AND ac.is_active = TRUE
    ORDER BY ac.display_order, at.display_order;
END;
$$ LANGUAGE plpgsql;