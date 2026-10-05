

CREATE TABLE IF NOT EXISTS employees (
    id SERIAL PRIMARY KEY,
    full_name TEXT NOT NULL,
    employee_code TEXT NOT NULL UNIQUE,
    date_of_birth TEXT,
    cccd TEXT,
    address TEXT,
    status TEXT NOT NULL DEFAULT 'Chính thức',
    position TEXT NOT NULL DEFAULT 'PG',
    department TEXT NOT NULL DEFAULT 'Kinh doanh',
    work_location TEXT NOT NULL DEFAULT '',
    province TEXT,
    area TEXT,
    created_date TEXT,
    probation_date TEXT,
    official_date TEXT,
    resign_date TEXT,
    resign_reason TEXT,
    phone TEXT,
    email TEXT,
    password TEXT DEFAULT '1111',
    avatar_url TEXT,
    store_code TEXT,
    geo_position TEXT,
    score INTEGER NOT NULL DEFAULT 0,
    rank_level TEXT,
    is_active INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    employee_id INTEGER,
    is_active INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS permissions (
    id SERIAL PRIMARY KEY,
    position TEXT NOT NULL UNIQUE,
    description TEXT,
    can_attendance INTEGER NOT NULL DEFAULT 0,
    can_report INTEGER NOT NULL DEFAULT 0,
    can_manage_attendance INTEGER NOT NULL DEFAULT 0,
    can_employees INTEGER NOT NULL DEFAULT 0,
    can_more INTEGER NOT NULL DEFAULT 0,
    can_crud INTEGER NOT NULL DEFAULT 0,
    can_switch_store INTEGER NOT NULL DEFAULT 0,
    can_store_list INTEGER NOT NULL DEFAULT 0,
    can_product_list INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS stores (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    store_code TEXT NOT NULL UNIQUE,
    store_group TEXT NOT NULL DEFAULT 'I',
    latitude REAL,
    longitude REAL,
    province TEXT,
    sup TEXT,
    status TEXT NOT NULL DEFAULT 'Hoạt động',
    open_date TEXT,
    close_date TEXT,
    store_type TEXT,
    address TEXT,
    phone TEXT,
    owner TEXT,
    tax_code TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS store_managers (
    id SERIAL PRIMARY KEY,
    store_id INTEGER NOT NULL,
    employee_id INTEGER NOT NULL,
    store_role TEXT NOT NULL DEFAULT 'PG',
    FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE,
    FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE,
    UNIQUE(store_id, employee_id)
);

CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    unit TEXT NOT NULL DEFAULT 'Lon',
    price_with_vat REAL NOT NULL DEFAULT 0,
    product_condition TEXT,
    product_group TEXT NOT NULL DEFAULT 'DELI',
    barcode TEXT,
    image_url TEXT,
    conversions_json TEXT,
    stock_quantity REAL NOT NULL DEFAULT 0,
    low_stock_threshold REAL NOT NULL DEFAULT 5,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS work_shifts (
    id SERIAL PRIMARY KEY,
    excel_id TEXT,
    name TEXT NOT NULL,
    shift_code TEXT,
    start_hour INTEGER NOT NULL,
    start_minute INTEGER NOT NULL DEFAULT 0,
    end_hour INTEGER NOT NULL,
    end_minute INTEGER NOT NULL DEFAULT 0,
    store_name TEXT,
    store_id INTEGER REFERENCES stores(id) ON DELETE SET NULL
);
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_name='work_shifts' AND column_name='store_id') THEN
    ALTER TABLE work_shifts ADD COLUMN store_id INTEGER REFERENCES stores(id) ON DELETE SET NULL;
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS attendances (
    id SERIAL PRIMARY KEY,
    excel_id TEXT,
    employee_id INTEGER NOT NULL,
    attend_date TEXT NOT NULL,
    shift_name TEXT,
    shift_time_range TEXT,
    coordinates TEXT,
    distance_in REAL,
    check_in_time TEXT,
    check_in_diff INTEGER,
    check_in_status TEXT,
    distance_out REAL,
    check_out_time TEXT,
    check_out_diff INTEGER,
    check_out_status TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS sales_reports (
    id SERIAL PRIMARY KEY,
    excel_id TEXT,
    report_date TEXT NOT NULL,
    pg_name TEXT NOT NULL,
    store_name TEXT,
    nu INTEGER NOT NULL DEFAULT 0,
    sale_out REAL NOT NULL DEFAULT 0,
    store_code TEXT,
    report_month INTEGER,
    revenue REAL NOT NULL DEFAULT 0,
    points INTEGER NOT NULL DEFAULT 0,
    employee_code TEXT,
    created_by INTEGER,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS sale_items (
    id SERIAL PRIMARY KEY,
    excel_id TEXT,
    report_id INTEGER NOT NULL,
    report_excel_id TEXT,
    product_id INTEGER,
    product_name TEXT NOT NULL,
    unit TEXT,
    quantity INTEGER NOT NULL DEFAULT 0,
    unit_price REAL NOT NULL DEFAULT 0,
    product_group TEXT,
    store_code TEXT,
    FOREIGN KEY (report_id) REFERENCES sales_reports(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS community_posts (
    id SERIAL PRIMARY KEY,
    excel_id TEXT,
    author_id INTEGER,
    author_name TEXT NOT NULL,
    employee_code TEXT,
    content TEXT,
    image_url TEXT,
    like_count INTEGER NOT NULL DEFAULT 0,
    comment_count INTEGER NOT NULL DEFAULT 0,
    points INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS comments (
    id SERIAL PRIMARY KEY,
    excel_id TEXT,
    comment_ref_id TEXT,
    post_id INTEGER,
    content TEXT,
    action TEXT,
    image_url TEXT,
    video_url TEXT,
    document_url TEXT,
    employee_code TEXT,
    author_name TEXT,
    points INTEGER NOT NULL DEFAULT 0,
    like_count INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (post_id) REFERENCES community_posts(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS post_likes (
    id SERIAL PRIMARY KEY,
    excel_id TEXT,
    ref_id TEXT,
    employee_code TEXT,
    full_name TEXT,
    points INTEGER NOT NULL DEFAULT 0,
    post_id INTEGER,
    user_id INTEGER,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (post_id) REFERENCES community_posts(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS course_titles (
    id SERIAL PRIMARY KEY,
    excel_id TEXT UNIQUE,
    title TEXT NOT NULL,
    access_level TEXT,
    image_url TEXT,
    description TEXT,
    rating REAL,
    target_group TEXT
);

CREATE TABLE IF NOT EXISTS course_contents (
    id SERIAL PRIMARY KEY,
    excel_id TEXT UNIQUE,
    title_id TEXT,
    title TEXT NOT NULL,
    detail_html TEXT,
    points INTEGER NOT NULL DEFAULT 0,
    attachment_type TEXT,
    image_url TEXT,
    video_url TEXT,
    file_url TEXT,
    embed_code TEXT,
    status TEXT DEFAULT 'Đang kiểm tra',
    FOREIGN KEY (title_id) REFERENCES course_titles(excel_id)
);

CREATE TABLE IF NOT EXISTS course_enrollments (
    id SERIAL PRIMARY KEY,
    excel_id TEXT,
    title_id TEXT,
    employee_code TEXT,
    full_name TEXT,
    enrolled_at TEXT
);

CREATE TABLE IF NOT EXISTS course_completions (
    id SERIAL PRIMARY KEY,
    excel_id TEXT,
    title_id TEXT,
    content_id TEXT,
    employee_code TEXT,
    full_name TEXT,
    completed_at TEXT,
    points INTEGER NOT NULL DEFAULT 0,
    content_name TEXT
);

CREATE TABLE IF NOT EXISTS quiz_questions (
    id SERIAL PRIMARY KEY,
    question_type TEXT DEFAULT 'TN',
    question TEXT NOT NULL,
    option_a TEXT,
    option_b TEXT,
    option_c TEXT,
    option_d TEXT,
    correct_answer TEXT,
    points INTEGER NOT NULL DEFAULT 0,
    content_id TEXT,
    question_number INTEGER
);

CREATE TABLE IF NOT EXISTS quiz_results (
    id SERIAL PRIMARY KEY,
    submitted_at TEXT,
    employee_code TEXT,
    full_name TEXT,
    store_name TEXT,
    phone TEXT,
    content_id TEXT,
    score TEXT,
    answers_json TEXT
);

CREATE TABLE IF NOT EXISTS class_schedules (
    id SERIAL PRIMARY KEY,
    excel_id TEXT UNIQUE,
    start_date TEXT,
    start_time TEXT,
    end_date TEXT,
    end_time TEXT,
    content TEXT,
    link TEXT,
    attendance_file TEXT
);

CREATE TABLE IF NOT EXISTS class_attendances (
    id SERIAL PRIMARY KEY,
    schedule_id TEXT,
    attendance_id TEXT,
    employee_code TEXT,
    full_name TEXT,
    store_name TEXT,
    content TEXT,
    action TEXT,
    attend_time TEXT,
    attend_date TEXT
);

CREATE TABLE IF NOT EXISTS ai_tools (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    link TEXT
);

CREATE TABLE IF NOT EXISTS ai_usage_logs (
    id SERIAL PRIMARY KEY,
    excel_id TEXT,
    employee_code TEXT,
    full_name TEXT,
    store_name TEXT,
    ai_name TEXT,
    used_at TEXT,
    points INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS lessons (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    thumbnail_url TEXT NOT NULL DEFAULT '',
    target_role TEXT NOT NULL DEFAULT 'ALL',
    is_restricted INTEGER NOT NULL DEFAULT 0,
    video_url TEXT
);

CREATE TABLE IF NOT EXISTS training_events (
    id SERIAL PRIMARY KEY,
    event_date TEXT NOT NULL,
    title TEXT NOT NULL,
    created_by INTEGER,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
);

-- Migration: add columns to pre-existing tables from before those columns
-- were introduced (CREATE TABLE IF NOT EXISTS is a no-op on those, so the
-- columns would otherwise never appear — first store_code broke the
-- indexes below, then password broke the login auto-provision flow, so
-- the rest of employees' newer columns are guarded here too to avoid
-- finding out about each one via a production crash).
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='employees' AND column_name='date_of_birth') THEN
        ALTER TABLE employees ADD COLUMN date_of_birth TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='employees' AND column_name='cccd') THEN
        ALTER TABLE employees ADD COLUMN cccd TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='employees' AND column_name='address') THEN
        ALTER TABLE employees ADD COLUMN address TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='employees' AND column_name='status') THEN
        ALTER TABLE employees ADD COLUMN status TEXT NOT NULL DEFAULT 'Chính thức';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='employees' AND column_name='position') THEN
        ALTER TABLE employees ADD COLUMN position TEXT NOT NULL DEFAULT 'PG';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='employees' AND column_name='department') THEN
        ALTER TABLE employees ADD COLUMN department TEXT NOT NULL DEFAULT 'Kinh doanh';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='employees' AND column_name='work_location') THEN
        ALTER TABLE employees ADD COLUMN work_location TEXT NOT NULL DEFAULT '';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='employees' AND column_name='province') THEN
        ALTER TABLE employees ADD COLUMN province TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='employees' AND column_name='area') THEN
        ALTER TABLE employees ADD COLUMN area TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='employees' AND column_name='created_date') THEN
        ALTER TABLE employees ADD COLUMN created_date TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='employees' AND column_name='probation_date') THEN
        ALTER TABLE employees ADD COLUMN probation_date TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='employees' AND column_name='official_date') THEN
        ALTER TABLE employees ADD COLUMN official_date TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='employees' AND column_name='resign_date') THEN
        ALTER TABLE employees ADD COLUMN resign_date TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='employees' AND column_name='resign_reason') THEN
        ALTER TABLE employees ADD COLUMN resign_reason TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='employees' AND column_name='phone') THEN
        ALTER TABLE employees ADD COLUMN phone TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='employees' AND column_name='email') THEN
        ALTER TABLE employees ADD COLUMN email TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='employees' AND column_name='password') THEN
        ALTER TABLE employees ADD COLUMN password TEXT DEFAULT '1111';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='employees' AND column_name='avatar_url') THEN
        ALTER TABLE employees ADD COLUMN avatar_url TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='employees' AND column_name='store_code') THEN
        ALTER TABLE employees ADD COLUMN store_code TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='employees' AND column_name='geo_position') THEN
        ALTER TABLE employees ADD COLUMN geo_position TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='employees' AND column_name='score') THEN
        ALTER TABLE employees ADD COLUMN score INTEGER NOT NULL DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='employees' AND column_name='rank_level') THEN
        ALTER TABLE employees ADD COLUMN rank_level TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='employees' AND column_name='is_active') THEN
        ALTER TABLE employees ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='sales_reports' AND column_name='store_code') THEN
        ALTER TABLE sales_reports ADD COLUMN store_code TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='sale_items' AND column_name='store_code') THEN
        ALTER TABLE sale_items ADD COLUMN store_code TEXT;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_employees_code ON employees(employee_code);
CREATE INDEX IF NOT EXISTS idx_employees_position ON employees(position);
CREATE INDEX IF NOT EXISTS idx_employees_store ON employees(store_code);
CREATE INDEX IF NOT EXISTS idx_attendances_date ON attendances(attend_date);
CREATE INDEX IF NOT EXISTS idx_attendances_employee ON attendances(employee_id);
CREATE INDEX IF NOT EXISTS idx_sales_reports_date ON sales_reports(report_date);
CREATE INDEX IF NOT EXISTS idx_sales_reports_store ON sales_reports(store_code);
CREATE INDEX IF NOT EXISTS idx_sale_items_report ON sale_items(report_id);
CREATE INDEX IF NOT EXISTS idx_community_posts_created ON community_posts(created_at);
CREATE INDEX IF NOT EXISTS idx_training_events_date ON training_events(event_date);
CREATE INDEX IF NOT EXISTS idx_store_managers_store ON store_managers(store_id);
CREATE INDEX IF NOT EXISTS idx_course_contents_title ON course_contents(title_id);
CREATE INDEX IF NOT EXISTS idx_quiz_questions_content ON quiz_questions(content_id);
CREATE INDEX IF NOT EXISTS idx_class_attendances_schedule ON class_attendances(schedule_id);

-- Migration: add store_role to existing store_managers if missing
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='store_managers' AND column_name='store_role') THEN
        ALTER TABLE store_managers ADD COLUMN store_role TEXT NOT NULL DEFAULT 'PG';
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS employee_schedules (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    shift_id INTEGER NOT NULL REFERENCES work_shifts(id) ON DELETE CASCADE,
    work_date DATE NOT NULL,
    note TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(employee_id, work_date)
);
CREATE INDEX IF NOT EXISTS idx_employee_schedules_date ON employee_schedules(work_date);
CREATE INDEX IF NOT EXISTS idx_employee_schedules_employee ON employee_schedules(employee_id);

-- Single-row config for an e-invoice provider (MISA meInvoice / VNPT / Viettel...).
-- Storing credentials only; the app never talks to the tax authority directly —
-- only to whichever licensed provider the business has a contract with.
CREATE TABLE IF NOT EXISTS einvoice_settings (
    id SERIAL PRIMARY KEY,
    provider TEXT NOT NULL DEFAULT 'misa',
    tax_code TEXT,
    api_base_url TEXT,
    api_key TEXT,
    username TEXT,
    is_active INTEGER NOT NULL DEFAULT 0,
    updated_by INTEGER,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE SET NULL
);

-- Migration: seller/invoice-template details needed to build a real Viettel
-- S-Invoice createInvoice request (generalInvoiceInfo/sellerInfo fields per
-- Viettel's documented schema) — the original columns above only covered
-- generic connection details, not what's needed to actually construct a
-- provider-specific invoice payload.
ALTER TABLE einvoice_settings ADD COLUMN IF NOT EXISTS seller_legal_name TEXT;
ALTER TABLE einvoice_settings ADD COLUMN IF NOT EXISTS seller_address TEXT;
ALTER TABLE einvoice_settings ADD COLUMN IF NOT EXISTS seller_phone TEXT;
ALTER TABLE einvoice_settings ADD COLUMN IF NOT EXISTS seller_email TEXT;
ALTER TABLE einvoice_settings ADD COLUMN IF NOT EXISTS seller_bank_name TEXT;
ALTER TABLE einvoice_settings ADD COLUMN IF NOT EXISTS seller_bank_account TEXT;
ALTER TABLE einvoice_settings ADD COLUMN IF NOT EXISTS invoice_template_code TEXT;
ALTER TABLE einvoice_settings ADD COLUMN IF NOT EXISTS invoice_series TEXT;
ALTER TABLE einvoice_settings ADD COLUMN IF NOT EXISTS vat_percent REAL NOT NULL DEFAULT 8;

-- Migration: extra per-provider credentials that don't fit the generic
-- username/api_key pair — MISA meInvoice needs a separate partner "appid"
-- (and optionally a signing PIN) alongside the merchant's own login, and
-- VNPT Invoice's ImportAndPublishInv call needs a separate Account/ACpass
-- service credential alongside the merchant's own username/pass.
ALTER TABLE einvoice_settings ADD COLUMN IF NOT EXISTS misa_app_id TEXT;
ALTER TABLE einvoice_settings ADD COLUMN IF NOT EXISTS misa_pin_code TEXT;
ALTER TABLE einvoice_settings ADD COLUMN IF NOT EXISTS vnpt_account TEXT;
ALTER TABLE einvoice_settings ADD COLUMN IF NOT EXISTS vnpt_account_pass TEXT;

-- Draft e-invoice issuance attempts for a sales report/order. This is a
-- best-effort integration against whichever generic endpoint is configured
-- in einvoice_settings — it has not been validated against any specific
-- licensed provider's certified schema, so "issued" here means "the
-- provider endpoint accepted our request", not "this is a tax-valid
-- invoice". Kept as its own append-only log rather than a single column
-- on sales_reports so a failed attempt can be retried without losing the
-- history of previous tries.
CREATE TABLE IF NOT EXISTS einvoice_records (
    id SERIAL PRIMARY KEY,
    report_id INTEGER NOT NULL REFERENCES sales_reports(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'failed',
    invoice_number TEXT,
    provider TEXT,
    error_message TEXT,
    response_snippet TEXT,
    issued_at TEXT,
    created_by INTEGER,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_einvoice_records_report ON einvoice_records(report_id);

-- Migration: record how a sale was paid (cash / bank transfer) from the
-- Bán hàng POS checkout — previously collected in the UI and discarded.
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='sales_reports' AND column_name='payment_method') THEN
        ALTER TABLE sales_reports ADD COLUMN payment_method TEXT;
    END IF;
END $$;

-- Migration: guard columns on products / stores / work_shifts /
-- community_posts / attendances that predate their introduction.
-- CREATE TABLE IF NOT EXISTS is a no-op on tables that already exist, so
-- any column only present in the CREATE TABLE statement above never
-- appeared on production databases created before that column was added,
-- causing psycopg.errors.UndefinedColumn crashes on GET/POST
-- /api/products, /api/stores, /api/shifts, /api/posts and attendance
-- queries. Every column on these five tables is guarded here (not just
-- the ones already observed crashing) to avoid finding the rest one
-- production incident at a time.
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='products' AND column_name='product_condition') THEN
        ALTER TABLE products ADD COLUMN product_condition TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='products' AND column_name='image_url') THEN
        ALTER TABLE products ADD COLUMN image_url TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='products' AND column_name='conversions_json') THEN
        ALTER TABLE products ADD COLUMN conversions_json TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='stores' AND column_name='province') THEN
        ALTER TABLE stores ADD COLUMN province TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='stores' AND column_name='sup') THEN
        ALTER TABLE stores ADD COLUMN sup TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='stores' AND column_name='store_type') THEN
        ALTER TABLE stores ADD COLUMN store_type TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='stores' AND column_name='owner') THEN
        ALTER TABLE stores ADD COLUMN owner TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='stores' AND column_name='tax_code') THEN
        ALTER TABLE stores ADD COLUMN tax_code TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='stores' AND column_name='open_date') THEN
        ALTER TABLE stores ADD COLUMN open_date TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='stores' AND column_name='close_date') THEN
        ALTER TABLE stores ADD COLUMN close_date TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='stores' AND column_name='address') THEN
        ALTER TABLE stores ADD COLUMN address TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='stores' AND column_name='phone') THEN
        ALTER TABLE stores ADD COLUMN phone TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='work_shifts' AND column_name='shift_code') THEN
        ALTER TABLE work_shifts ADD COLUMN shift_code TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='work_shifts' AND column_name='excel_id') THEN
        ALTER TABLE work_shifts ADD COLUMN excel_id TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='work_shifts' AND column_name='store_name') THEN
        ALTER TABLE work_shifts ADD COLUMN store_name TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='community_posts' AND column_name='image_url') THEN
        ALTER TABLE community_posts ADD COLUMN image_url TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='community_posts' AND column_name='excel_id') THEN
        ALTER TABLE community_posts ADD COLUMN excel_id TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='community_posts' AND column_name='author_id') THEN
        ALTER TABLE community_posts ADD COLUMN author_id INTEGER;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='community_posts' AND column_name='employee_code') THEN
        ALTER TABLE community_posts ADD COLUMN employee_code TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='community_posts' AND column_name='content') THEN
        ALTER TABLE community_posts ADD COLUMN content TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='community_posts' AND column_name='like_count') THEN
        ALTER TABLE community_posts ADD COLUMN like_count INTEGER NOT NULL DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='community_posts' AND column_name='comment_count') THEN
        ALTER TABLE community_posts ADD COLUMN comment_count INTEGER NOT NULL DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='community_posts' AND column_name='points') THEN
        ALTER TABLE community_posts ADD COLUMN points INTEGER NOT NULL DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='attendances' AND column_name='excel_id') THEN
        ALTER TABLE attendances ADD COLUMN excel_id TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='attendances' AND column_name='shift_name') THEN
        ALTER TABLE attendances ADD COLUMN shift_name TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='attendances' AND column_name='shift_time_range') THEN
        ALTER TABLE attendances ADD COLUMN shift_time_range TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='attendances' AND column_name='coordinates') THEN
        ALTER TABLE attendances ADD COLUMN coordinates TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='attendances' AND column_name='distance_in') THEN
        ALTER TABLE attendances ADD COLUMN distance_in REAL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='attendances' AND column_name='check_in_time') THEN
        ALTER TABLE attendances ADD COLUMN check_in_time TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='attendances' AND column_name='check_in_diff') THEN
        ALTER TABLE attendances ADD COLUMN check_in_diff INTEGER;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='attendances' AND column_name='check_in_status') THEN
        ALTER TABLE attendances ADD COLUMN check_in_status TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='attendances' AND column_name='distance_out') THEN
        ALTER TABLE attendances ADD COLUMN distance_out REAL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='attendances' AND column_name='check_out_time') THEN
        ALTER TABLE attendances ADD COLUMN check_out_time TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='attendances' AND column_name='check_out_diff') THEN
        ALTER TABLE attendances ADD COLUMN check_out_diff INTEGER;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='attendances' AND column_name='check_out_status') THEN
        ALTER TABLE attendances ADD COLUMN check_out_status TEXT;
    END IF;
END $$;

-- Migration: the previous migration pass assumed sales_reports/sale_items/
-- stores/permissions only needed the couple of columns already guarded
-- above, but a live diagnose run turned up psycopg.errors.UndefinedColumn
-- on stores.status and sales_reports.store_name/sale_out too (the POS
-- checkout's INSERT failed outright with "Bán hàng thất bại"). Given two
-- rounds of surprises now, guard every remaining column on every table
-- instead of continuing to find them one crash at a time.
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='stores' AND column_name='status') THEN
        ALTER TABLE stores ADD COLUMN status TEXT NOT NULL DEFAULT 'Hoạt động';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='sales_reports' AND column_name='excel_id') THEN
        ALTER TABLE sales_reports ADD COLUMN excel_id TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='sales_reports' AND column_name='store_name') THEN
        ALTER TABLE sales_reports ADD COLUMN store_name TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='sales_reports' AND column_name='nu') THEN
        ALTER TABLE sales_reports ADD COLUMN nu INTEGER NOT NULL DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='sales_reports' AND column_name='sale_out') THEN
        ALTER TABLE sales_reports ADD COLUMN sale_out REAL NOT NULL DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='sales_reports' AND column_name='report_month') THEN
        ALTER TABLE sales_reports ADD COLUMN report_month INTEGER;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='sales_reports' AND column_name='revenue') THEN
        ALTER TABLE sales_reports ADD COLUMN revenue REAL NOT NULL DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='sales_reports' AND column_name='points') THEN
        ALTER TABLE sales_reports ADD COLUMN points INTEGER NOT NULL DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='sales_reports' AND column_name='employee_code') THEN
        ALTER TABLE sales_reports ADD COLUMN employee_code TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='sales_reports' AND column_name='created_by') THEN
        ALTER TABLE sales_reports ADD COLUMN created_by INTEGER REFERENCES users(id) ON DELETE SET NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='sale_items' AND column_name='excel_id') THEN
        ALTER TABLE sale_items ADD COLUMN excel_id TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='sale_items' AND column_name='report_excel_id') THEN
        ALTER TABLE sale_items ADD COLUMN report_excel_id TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='sale_items' AND column_name='product_id') THEN
        ALTER TABLE sale_items ADD COLUMN product_id INTEGER;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='sale_items' AND column_name='unit') THEN
        ALTER TABLE sale_items ADD COLUMN unit TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='sale_items' AND column_name='quantity') THEN
        ALTER TABLE sale_items ADD COLUMN quantity INTEGER NOT NULL DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='sale_items' AND column_name='unit_price') THEN
        ALTER TABLE sale_items ADD COLUMN unit_price REAL NOT NULL DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='sale_items' AND column_name='product_group') THEN
        ALTER TABLE sale_items ADD COLUMN product_group TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='permissions' AND column_name='description') THEN
        ALTER TABLE permissions ADD COLUMN description TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='permissions' AND column_name='can_attendance') THEN
        ALTER TABLE permissions ADD COLUMN can_attendance INTEGER NOT NULL DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='permissions' AND column_name='can_report') THEN
        ALTER TABLE permissions ADD COLUMN can_report INTEGER NOT NULL DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='permissions' AND column_name='can_manage_attendance') THEN
        ALTER TABLE permissions ADD COLUMN can_manage_attendance INTEGER NOT NULL DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='permissions' AND column_name='can_employees') THEN
        ALTER TABLE permissions ADD COLUMN can_employees INTEGER NOT NULL DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='permissions' AND column_name='can_more') THEN
        ALTER TABLE permissions ADD COLUMN can_more INTEGER NOT NULL DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='permissions' AND column_name='can_crud') THEN
        ALTER TABLE permissions ADD COLUMN can_crud INTEGER NOT NULL DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='permissions' AND column_name='can_switch_store') THEN
        ALTER TABLE permissions ADD COLUMN can_switch_store INTEGER NOT NULL DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='permissions' AND column_name='can_store_list') THEN
        ALTER TABLE permissions ADD COLUMN can_store_list INTEGER NOT NULL DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='permissions' AND column_name='can_product_list') THEN
        ALTER TABLE permissions ADD COLUMN can_product_list INTEGER NOT NULL DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='comments' AND column_name='excel_id') THEN
        ALTER TABLE comments ADD COLUMN excel_id TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='comments' AND column_name='comment_ref_id') THEN
        ALTER TABLE comments ADD COLUMN comment_ref_id TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='comments' AND column_name='post_id') THEN
        ALTER TABLE comments ADD COLUMN post_id INTEGER REFERENCES community_posts(id) ON DELETE CASCADE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='comments' AND column_name='content') THEN
        ALTER TABLE comments ADD COLUMN content TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='comments' AND column_name='action') THEN
        ALTER TABLE comments ADD COLUMN action TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='comments' AND column_name='image_url') THEN
        ALTER TABLE comments ADD COLUMN image_url TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='comments' AND column_name='video_url') THEN
        ALTER TABLE comments ADD COLUMN video_url TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='comments' AND column_name='document_url') THEN
        ALTER TABLE comments ADD COLUMN document_url TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='comments' AND column_name='employee_code') THEN
        ALTER TABLE comments ADD COLUMN employee_code TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='comments' AND column_name='author_name') THEN
        ALTER TABLE comments ADD COLUMN author_name TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='comments' AND column_name='points') THEN
        ALTER TABLE comments ADD COLUMN points INTEGER NOT NULL DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='comments' AND column_name='like_count') THEN
        ALTER TABLE comments ADD COLUMN like_count INTEGER NOT NULL DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='post_likes' AND column_name='excel_id') THEN
        ALTER TABLE post_likes ADD COLUMN excel_id TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='post_likes' AND column_name='ref_id') THEN
        ALTER TABLE post_likes ADD COLUMN ref_id TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='post_likes' AND column_name='employee_code') THEN
        ALTER TABLE post_likes ADD COLUMN employee_code TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='post_likes' AND column_name='full_name') THEN
        ALTER TABLE post_likes ADD COLUMN full_name TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='post_likes' AND column_name='points') THEN
        ALTER TABLE post_likes ADD COLUMN points INTEGER NOT NULL DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='post_likes' AND column_name='post_id') THEN
        ALTER TABLE post_likes ADD COLUMN post_id INTEGER REFERENCES community_posts(id) ON DELETE CASCADE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='post_likes' AND column_name='user_id') THEN
        ALTER TABLE post_likes ADD COLUMN user_id INTEGER;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='course_titles' AND column_name='access_level') THEN
        ALTER TABLE course_titles ADD COLUMN access_level TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='course_titles' AND column_name='image_url') THEN
        ALTER TABLE course_titles ADD COLUMN image_url TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='course_titles' AND column_name='description') THEN
        ALTER TABLE course_titles ADD COLUMN description TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='course_titles' AND column_name='rating') THEN
        ALTER TABLE course_titles ADD COLUMN rating REAL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='course_titles' AND column_name='target_group') THEN
        ALTER TABLE course_titles ADD COLUMN target_group TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='course_contents' AND column_name='title_id') THEN
        ALTER TABLE course_contents ADD COLUMN title_id TEXT REFERENCES course_titles(excel_id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='course_contents' AND column_name='detail_html') THEN
        ALTER TABLE course_contents ADD COLUMN detail_html TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='course_contents' AND column_name='points') THEN
        ALTER TABLE course_contents ADD COLUMN points INTEGER NOT NULL DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='course_contents' AND column_name='attachment_type') THEN
        ALTER TABLE course_contents ADD COLUMN attachment_type TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='course_contents' AND column_name='image_url') THEN
        ALTER TABLE course_contents ADD COLUMN image_url TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='course_contents' AND column_name='video_url') THEN
        ALTER TABLE course_contents ADD COLUMN video_url TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='course_contents' AND column_name='file_url') THEN
        ALTER TABLE course_contents ADD COLUMN file_url TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='course_contents' AND column_name='embed_code') THEN
        ALTER TABLE course_contents ADD COLUMN embed_code TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='course_contents' AND column_name='status') THEN
        ALTER TABLE course_contents ADD COLUMN status TEXT DEFAULT 'Đang kiểm tra';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='course_enrollments' AND column_name='excel_id') THEN
        ALTER TABLE course_enrollments ADD COLUMN excel_id TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='course_enrollments' AND column_name='title_id') THEN
        ALTER TABLE course_enrollments ADD COLUMN title_id TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='course_enrollments' AND column_name='employee_code') THEN
        ALTER TABLE course_enrollments ADD COLUMN employee_code TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='course_enrollments' AND column_name='full_name') THEN
        ALTER TABLE course_enrollments ADD COLUMN full_name TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='course_enrollments' AND column_name='enrolled_at') THEN
        ALTER TABLE course_enrollments ADD COLUMN enrolled_at TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='course_completions' AND column_name='excel_id') THEN
        ALTER TABLE course_completions ADD COLUMN excel_id TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='course_completions' AND column_name='title_id') THEN
        ALTER TABLE course_completions ADD COLUMN title_id TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='course_completions' AND column_name='content_id') THEN
        ALTER TABLE course_completions ADD COLUMN content_id TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='course_completions' AND column_name='employee_code') THEN
        ALTER TABLE course_completions ADD COLUMN employee_code TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='course_completions' AND column_name='full_name') THEN
        ALTER TABLE course_completions ADD COLUMN full_name TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='course_completions' AND column_name='completed_at') THEN
        ALTER TABLE course_completions ADD COLUMN completed_at TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='course_completions' AND column_name='points') THEN
        ALTER TABLE course_completions ADD COLUMN points INTEGER NOT NULL DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='course_completions' AND column_name='content_name') THEN
        ALTER TABLE course_completions ADD COLUMN content_name TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='quiz_questions' AND column_name='question_type') THEN
        ALTER TABLE quiz_questions ADD COLUMN question_type TEXT DEFAULT 'TN';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='quiz_questions' AND column_name='option_a') THEN
        ALTER TABLE quiz_questions ADD COLUMN option_a TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='quiz_questions' AND column_name='option_b') THEN
        ALTER TABLE quiz_questions ADD COLUMN option_b TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='quiz_questions' AND column_name='option_c') THEN
        ALTER TABLE quiz_questions ADD COLUMN option_c TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='quiz_questions' AND column_name='option_d') THEN
        ALTER TABLE quiz_questions ADD COLUMN option_d TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='quiz_questions' AND column_name='correct_answer') THEN
        ALTER TABLE quiz_questions ADD COLUMN correct_answer TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='quiz_questions' AND column_name='points') THEN
        ALTER TABLE quiz_questions ADD COLUMN points INTEGER NOT NULL DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='quiz_questions' AND column_name='content_id') THEN
        ALTER TABLE quiz_questions ADD COLUMN content_id TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='quiz_questions' AND column_name='question_number') THEN
        ALTER TABLE quiz_questions ADD COLUMN question_number INTEGER;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='quiz_results' AND column_name='submitted_at') THEN
        ALTER TABLE quiz_results ADD COLUMN submitted_at TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='quiz_results' AND column_name='employee_code') THEN
        ALTER TABLE quiz_results ADD COLUMN employee_code TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='quiz_results' AND column_name='full_name') THEN
        ALTER TABLE quiz_results ADD COLUMN full_name TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='quiz_results' AND column_name='store_name') THEN
        ALTER TABLE quiz_results ADD COLUMN store_name TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='quiz_results' AND column_name='phone') THEN
        ALTER TABLE quiz_results ADD COLUMN phone TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='quiz_results' AND column_name='content_id') THEN
        ALTER TABLE quiz_results ADD COLUMN content_id TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='quiz_results' AND column_name='score') THEN
        ALTER TABLE quiz_results ADD COLUMN score TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='quiz_results' AND column_name='answers_json') THEN
        ALTER TABLE quiz_results ADD COLUMN answers_json TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='class_schedules' AND column_name='start_date') THEN
        ALTER TABLE class_schedules ADD COLUMN start_date TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='class_schedules' AND column_name='start_time') THEN
        ALTER TABLE class_schedules ADD COLUMN start_time TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='class_schedules' AND column_name='end_date') THEN
        ALTER TABLE class_schedules ADD COLUMN end_date TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='class_schedules' AND column_name='end_time') THEN
        ALTER TABLE class_schedules ADD COLUMN end_time TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='class_schedules' AND column_name='content') THEN
        ALTER TABLE class_schedules ADD COLUMN content TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='class_schedules' AND column_name='link') THEN
        ALTER TABLE class_schedules ADD COLUMN link TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='class_schedules' AND column_name='attendance_file') THEN
        ALTER TABLE class_schedules ADD COLUMN attendance_file TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='class_attendances' AND column_name='schedule_id') THEN
        ALTER TABLE class_attendances ADD COLUMN schedule_id TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='class_attendances' AND column_name='attendance_id') THEN
        ALTER TABLE class_attendances ADD COLUMN attendance_id TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='class_attendances' AND column_name='employee_code') THEN
        ALTER TABLE class_attendances ADD COLUMN employee_code TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='class_attendances' AND column_name='full_name') THEN
        ALTER TABLE class_attendances ADD COLUMN full_name TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='class_attendances' AND column_name='store_name') THEN
        ALTER TABLE class_attendances ADD COLUMN store_name TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='class_attendances' AND column_name='content') THEN
        ALTER TABLE class_attendances ADD COLUMN content TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='class_attendances' AND column_name='action') THEN
        ALTER TABLE class_attendances ADD COLUMN action TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='class_attendances' AND column_name='attend_time') THEN
        ALTER TABLE class_attendances ADD COLUMN attend_time TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='class_attendances' AND column_name='attend_date') THEN
        ALTER TABLE class_attendances ADD COLUMN attend_date TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='class_attendances' AND column_name='link') THEN
        ALTER TABLE class_attendances ADD COLUMN link TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='ai_tools' AND column_name='link') THEN
        ALTER TABLE ai_tools ADD COLUMN link TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='ai_usage_logs' AND column_name='excel_id') THEN
        ALTER TABLE ai_usage_logs ADD COLUMN excel_id TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='ai_usage_logs' AND column_name='employee_code') THEN
        ALTER TABLE ai_usage_logs ADD COLUMN employee_code TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='ai_usage_logs' AND column_name='full_name') THEN
        ALTER TABLE ai_usage_logs ADD COLUMN full_name TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='ai_usage_logs' AND column_name='store_name') THEN
        ALTER TABLE ai_usage_logs ADD COLUMN store_name TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='ai_usage_logs' AND column_name='ai_name') THEN
        ALTER TABLE ai_usage_logs ADD COLUMN ai_name TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='ai_usage_logs' AND column_name='used_at') THEN
        ALTER TABLE ai_usage_logs ADD COLUMN used_at TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='ai_usage_logs' AND column_name='points') THEN
        ALTER TABLE ai_usage_logs ADD COLUMN points INTEGER NOT NULL DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='lessons' AND column_name='thumbnail_url') THEN
        ALTER TABLE lessons ADD COLUMN thumbnail_url TEXT NOT NULL DEFAULT '';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='lessons' AND column_name='target_role') THEN
        ALTER TABLE lessons ADD COLUMN target_role TEXT NOT NULL DEFAULT 'ALL';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='lessons' AND column_name='is_restricted') THEN
        ALTER TABLE lessons ADD COLUMN is_restricted INTEGER NOT NULL DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='lessons' AND column_name='video_url') THEN
        ALTER TABLE lessons ADD COLUMN video_url TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='training_events' AND column_name='created_by') THEN
        ALTER TABLE training_events ADD COLUMN created_by INTEGER REFERENCES users(id) ON DELETE SET NULL;
    END IF;
END $$;

-- Migration: barcode field for the Bán hàng POS barcode scanner.
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='products' AND column_name='barcode') THEN
        ALTER TABLE products ADD COLUMN barcode TEXT;
    END IF;
END $$;

-- Leave requests (nghỉ phép): employee self-service request, manager
-- approves/rejects. store_code is denormalized from the employee at
-- request time so manager queries can filter by store without a join.
CREATE TABLE IF NOT EXISTS leave_requests (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    store_code TEXT,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    leave_type TEXT NOT NULL DEFAULT 'Nghỉ phép năm',
    reason TEXT,
    status TEXT NOT NULL DEFAULT 'pending',
    requested_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    approved_by INTEGER REFERENCES employees(id) ON DELETE SET NULL,
    approved_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_leave_requests_employee ON leave_requests(employee_id);
CREATE INDEX IF NOT EXISTS idx_leave_requests_store ON leave_requests(store_code);

-- Migration: inventory tracking columns on products, predates the
-- CREATE TABLE above on databases created before this feature existed.
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='products' AND column_name='stock_quantity') THEN
        ALTER TABLE products ADD COLUMN stock_quantity REAL NOT NULL DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='products' AND column_name='low_stock_threshold') THEN
        ALTER TABLE products ADD COLUMN low_stock_threshold REAL NOT NULL DEFAULT 5;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='sales_reports' AND column_name='discount_amount') THEN
        ALTER TABLE sales_reports ADD COLUMN discount_amount REAL NOT NULL DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='sales_reports' AND column_name='customer_name') THEN
        ALTER TABLE sales_reports ADD COLUMN customer_name TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                 WHERE table_name='sales_reports' AND column_name='customer_phone') THEN
        ALTER TABLE sales_reports ADD COLUMN customer_phone TEXT;
    END IF;
END $$;

-- Returns/refunds recorded against a sales report — a report can have
-- multiple partial returns over time; the report itself is never mutated.
CREATE TABLE IF NOT EXISTS report_returns (
    id SERIAL PRIMARY KEY,
    report_id INTEGER NOT NULL REFERENCES sales_reports(id) ON DELETE CASCADE,
    amount REAL NOT NULL DEFAULT 0,
    reason TEXT,
    created_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_report_returns_report ON report_returns(report_id);

-- Zalo Mini App: link an employee to their Zalo account (one-tap login)
ALTER TABLE employees ADD COLUMN IF NOT EXISTS zalo_id TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS idx_employees_zalo_id ON employees(zalo_id) WHERE zalo_id IS NOT NULL;
ALTER TABLE employees ADD COLUMN IF NOT EXISTS zalo_oa_id TEXT;  -- the employee's id as seen by the Official Account (needed to message them)

-- Zalo OA tokens rotate (the refresh token changes on every refresh), so the live pair lives here, seeded from env.
CREATE TABLE IF NOT EXISTS zalo_oa_tokens (
    id INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    access_token TEXT,
    refresh_token TEXT,
    expires_at TEXT,
    updated_at TEXT
);

CREATE TABLE IF NOT EXISTS zalo_oa_oauth (
    state TEXT PRIMARY KEY,
    verifier TEXT NOT NULL,
    created_at TEXT NOT NULL
);
ALTER TABLE zalo_oa_tokens ADD COLUMN IF NOT EXISTS oa_id TEXT;

CREATE TABLE IF NOT EXISTS zalo_oa_push_log (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER,
    ok INTEGER NOT NULL DEFAULT 0,
    detail TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Task assignment & store work tracking
CREATE TABLE IF NOT EXISTS tasks (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    store_code TEXT NOT NULL DEFAULT '',
    assignee_id INTEGER REFERENCES employees(id) ON DELETE SET NULL,
    assigned_by INTEGER REFERENCES employees(id) ON DELETE SET NULL,
    priority TEXT NOT NULL DEFAULT 'normal',      -- low | normal | high | urgent
    status TEXT NOT NULL DEFAULT 'todo',          -- todo | doing | done | cancelled
    due_at TEXT,
    recurrence TEXT NOT NULL DEFAULT 'none',      -- none | daily | weekly
    require_photo INTEGER NOT NULL DEFAULT 0,
    photo_urls TEXT NOT NULL DEFAULT '[]',        -- JSON array of uploaded file names (completion proof)
    completed_at TEXT,
    completion_note TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_tasks_assignee ON tasks(assignee_id, status);
CREATE INDEX IF NOT EXISTS idx_tasks_store ON tasks(store_code, status);
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS doer_ids TEXT NOT NULL DEFAULT '[]';  -- JSON array of employee ids who carried the task out

CREATE TABLE IF NOT EXISTS task_comments (
    id SERIAL PRIMARY KEY,
    task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    author_id INTEGER REFERENCES employees(id) ON DELETE SET NULL,
    body TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_task_comments_task ON task_comments(task_id);

-- In-app notifications (bell icon): one row per recipient. dedupe_key keeps reminders from repeating.
CREATE TABLE IF NOT EXISTS notifications (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    kind TEXT NOT NULL DEFAULT 'info',     -- assigned | done | comment | cancelled | reopened | due_soon | overdue
    title TEXT NOT NULL,
    body TEXT NOT NULL DEFAULT '',
    task_id INTEGER REFERENCES tasks(id) ON DELETE SET NULL,
    dedupe_key TEXT,
    is_read INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_notifications_dedupe ON notifications(employee_id, dedupe_key);
CREATE INDEX IF NOT EXISTS idx_notifications_employee ON notifications(employee_id, is_read, id DESC);

-- ---------------------------------------------------------------------------
-- Store operations: cash-fund reports, purchase orders + receiving, announcements
-- ---------------------------------------------------------------------------
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS link TEXT;

CREATE TABLE IF NOT EXISTS fund_reports (
    id SERIAL PRIMARY KEY,
    store_code TEXT NOT NULL,
    report_date TEXT NOT NULL,                 -- YYYY-MM-DD
    counts_json TEXT NOT NULL DEFAULT '{}',    -- {"500000": 3, "200000": 5, ...}
    other_amount REAL NOT NULL DEFAULT 0,      -- loose change not covered by denominations
    cash_total REAL NOT NULL DEFAULT 0,        -- recomputed server-side
    system_balance REAL NOT NULL DEFAULT 0,
    difference REAL NOT NULL DEFAULT 0,        -- cash_total - system_balance
    note TEXT,
    photo_urls TEXT NOT NULL DEFAULT '[]',
    status TEXT NOT NULL DEFAULT 'submitted',  -- submitted | approved | rejected
    submitted_by INTEGER REFERENCES employees(id) ON DELETE SET NULL,
    reviewed_by INTEGER REFERENCES employees(id) ON DELETE SET NULL,
    reviewed_at TEXT,
    review_note TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (store_code, report_date)
);
CREATE INDEX IF NOT EXISTS idx_fund_reports_date ON fund_reports(report_date, store_code);

CREATE TABLE IF NOT EXISTS fund_entries (
    id SERIAL PRIMARY KEY,
    store_code TEXT NOT NULL,
    entry_date TEXT NOT NULL,
    kind TEXT NOT NULL,                        -- in | out
    amount REAL NOT NULL,
    reason TEXT,
    photo_urls TEXT NOT NULL DEFAULT '[]',
    created_by INTEGER REFERENCES employees(id) ON DELETE SET NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_fund_entries_date ON fund_entries(store_code, entry_date);

CREATE TABLE IF NOT EXISTS purchase_orders (
    id SERIAL PRIMARY KEY,
    store_code TEXT NOT NULL,
    order_date TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'submitted',  -- submitted | approved | ordered | partial | delivered | cancelled
    supplier TEXT,
    note TEXT,
    created_by INTEGER REFERENCES employees(id) ON DELETE SET NULL,
    approved_by INTEGER REFERENCES employees(id) ON DELETE SET NULL,
    approved_at TEXT,
    ordered_at TEXT,
    received_at TEXT,
    received_by INTEGER REFERENCES employees(id) ON DELETE SET NULL,
    receipt_note TEXT,
    receipt_photos TEXT NOT NULL DEFAULT '[]',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_store ON purchase_orders(store_code, order_date);

CREATE TABLE IF NOT EXISTS purchase_order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
    product_id INTEGER,
    product_name TEXT NOT NULL,
    unit TEXT,
    qty REAL NOT NULL,
    qty_received REAL,
    note TEXT
);
CREATE INDEX IF NOT EXISTS idx_po_items_order ON purchase_order_items(order_id);

CREATE TABLE IF NOT EXISTS announcements (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    body TEXT NOT NULL DEFAULT '',
    image_urls TEXT NOT NULL DEFAULT '[]',
    audience_stores TEXT NOT NULL DEFAULT '[]',     -- [] = every store
    audience_positions TEXT NOT NULL DEFAULT '[]',  -- [] = every position
    pinned INTEGER NOT NULL DEFAULT 0,
    remind_at TEXT,
    created_by INTEGER REFERENCES employees(id) ON DELETE SET NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS announcement_reads (
    announcement_id INTEGER NOT NULL REFERENCES announcements(id) ON DELETE CASCADE,
    employee_id INTEGER NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    read_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (announcement_id, employee_id)
);

-- Migration: production has an "employees_position_check" CHECK constraint
-- that was never captured in this file (added directly on the VPS at some
-- point, not through this script), so it only allowed whatever subset of
-- position codes existed back then. It rejected 'SM' (Cửa hàng trưởng) with
-- a 500 the moment that code was exposed in the Flutter position picker,
-- even though 'SM' is already recognized everywhere else in the app
-- (Permission.storeRoleLabels, Employee.positionLabel, Permission.
-- defaultForPosition). Replace it with one that covers every code the
-- picker can actually send. DROP+ADD is the idempotent way to redefine a
-- CHECK constraint — Postgres has no "ADD CONSTRAINT IF NOT EXISTS".
ALTER TABLE employees DROP CONSTRAINT IF EXISTS employees_position_check;
ALTER TABLE employees ADD CONSTRAINT employees_position_check
    CHECK (position IN ('ADM', 'PG', 'TLD', 'SM', 'MNG', 'CS'));

CREATE TABLE IF NOT EXISTS zalo_oa_pending (
    app_user TEXT PRIMARY KEY,
    oa_user TEXT NOT NULL,
    created_at TEXT
);

CREATE TABLE IF NOT EXISTS oa_care_campaigns (
    id SERIAL PRIMARY KEY,
    body TEXT NOT NULL,
    image_url TEXT,
    period TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'sending',
    total INTEGER NOT NULL DEFAULT 0,
    ok_count INTEGER NOT NULL DEFAULT 0,
    fail_count INTEGER NOT NULL DEFAULT 0,
    errors TEXT,
    created_by INTEGER,
    created_at TEXT,
    finished_at TEXT
);

CREATE TABLE IF NOT EXISTS oa_seen_users (
    user_id TEXT PRIMARY KEY,
    first_seen TEXT,
    last_interaction TEXT,
    followed INTEGER NOT NULL DEFAULT 1
);

ALTER TABLE oa_seen_users ADD COLUMN IF NOT EXISTS app_user TEXT;

-- KPI theo cửa hàng / tháng (đơn vị: nghìn đồng), do admin nhập trong app.
CREATE TABLE IF NOT EXISTS store_kpi (
    store_code TEXT NOT NULL,
    month TEXT NOT NULL,
    store_name TEXT,
    region TEXT,
    kpi_total BIGINT,
    kpi_n1 BIGINT,
    kpi_sbps_n1 BIGINT,
    dst BIGINT,
    dst_sb BIGINT,
    dst_sbps BIGINT,
    ds_n1 BIGINT,
    ds_sbps_n1 BIGINT,
    stock_total BIGINT,
    stock_n1 BIGINT,
    updated_by INTEGER,
    updated_at TEXT,
    PRIMARY KEY (store_code, month)
);

CREATE TABLE IF NOT EXISTS members (
    id SERIAL PRIMARY KEY,
    zalo_id TEXT NOT NULL UNIQUE,
    phone TEXT NOT NULL UNIQUE,
    full_name TEXT NOT NULL,
    birthday TEXT,
    address TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE members ADD COLUMN IF NOT EXISTS address TEXT;

CREATE TABLE IF NOT EXISTS member_orders (
    id SERIAL PRIMARY KEY,
    member_id INTEGER NOT NULL REFERENCES members(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'placed',
    payment_method TEXT NOT NULL DEFAULT 'cod',
    note TEXT,
    recipient TEXT,
    phone TEXT,
    address TEXT,
    total REAL NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_member_orders_member ON member_orders(member_id);

CREATE TABLE IF NOT EXISTS member_order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES member_orders(id) ON DELETE CASCADE,
    product_id INTEGER,
    name TEXT NOT NULL,
    unit_price REAL NOT NULL DEFAULT 0,
    quantity INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS member_rewards (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    points INTEGER NOT NULL,
    active INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS member_redemptions (
    id SERIAL PRIMARY KEY,
    member_id INTEGER NOT NULL REFERENCES members(id) ON DELETE CASCADE,
    reward_id INTEGER,
    name TEXT NOT NULL,
    points INTEGER NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS app_migrations (
    name TEXT PRIMARY KEY,
    applied_at TEXT
);

-- One-off: remove the figures that were pre-loaded from the workbook (rows nobody saved from the app).
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM app_migrations WHERE name = 'kpi_seed_removed') THEN
        DELETE FROM store_kpi WHERE updated_by IS NULL;
        INSERT INTO app_migrations (name, applied_at) VALUES ('kpi_seed_removed', CURRENT_TIMESTAMP::text);
    END IF;
END $$;
