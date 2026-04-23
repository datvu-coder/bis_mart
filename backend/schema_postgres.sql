

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
    store_name TEXT
);

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
