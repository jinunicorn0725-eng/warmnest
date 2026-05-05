-- ====================================================================
-- 暖巢 Warmnest · Supabase 数据库初始化脚本
-- ====================================================================
-- 使用方法：
-- 1. 在 https://supabase.com 注册并新建一个 Project
-- 2. 进入 Project → SQL Editor → 新建查询
-- 3. 把本文件全部内容粘贴并运行 (Run)
-- 4. 进入 Project → Settings → API，复制 Project URL 与 anon public key
-- 5. 把它们填到 report.html 顶部 SUPABASE_URL / SUPABASE_ANON_KEY 即可
-- ====================================================================

-- ---------- 1. 上报记录表 ----------
CREATE TABLE IF NOT EXISTS public.reports (
  id          BIGSERIAL PRIMARY KEY,
  ref_id      TEXT        NOT NULL,                       -- 编号: WN-YYYY-MMDD-XXXX
  species     TEXT        NOT NULL,                       -- 动物种类
  found_at    TIMESTAMPTZ NOT NULL,                       -- 发现时间
  location    TEXT        NOT NULL,                       -- 具体位置
  description TEXT        NOT NULL,                       -- 状态描述
  contact     TEXT        NOT NULL,                       -- 联系电话（隐私字段）
  photo_url   TEXT,                                       -- 图片 URL（来自 Storage）
  title       TEXT,                                       -- 卡片标题（自动生成）
  status      TEXT        NOT NULL DEFAULT 'pending',     -- pending / following / rescued
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS reports_created_at_idx ON public.reports (created_at DESC);

-- ---------- 2. 行级安全 (RLS) ----------
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

-- 允许任何访客 (anon) 插入新上报
DROP POLICY IF EXISTS "anon insert reports" ON public.reports;
CREATE POLICY "anon insert reports"
  ON public.reports
  FOR INSERT
  TO anon
  WITH CHECK (true);

-- 允许任何访客 (anon) 查询上报
DROP POLICY IF EXISTS "anon select reports" ON public.reports;
CREATE POLICY "anon select reports"
  ON public.reports
  FOR SELECT
  TO anon
  USING (true);

-- ---------- 3. 列级权限：把 contact (手机号) 设为非公开 ----------
-- 普通访客读取时不会看到 contact 字段；只有 service_role 才能读
REVOKE SELECT ON public.reports FROM anon;
GRANT SELECT
  (id, ref_id, species, found_at, location, description, photo_url, title, status, created_at)
  ON public.reports TO anon;

-- 允许 anon 写入所有列（含 contact）
GRANT INSERT
  (ref_id, species, found_at, location, description, contact, photo_url, title, status)
  ON public.reports TO anon;

-- 允许使用序列
GRANT USAGE, SELECT ON SEQUENCE public.reports_id_seq TO anon;

-- ---------- 4. 存储桶：用于动物照片 ----------
INSERT INTO storage.buckets (id, name, public)
VALUES ('animal-photos', 'animal-photos', true)
ON CONFLICT (id) DO NOTHING;

-- 允许任何访客上传到 animal-photos 桶
DROP POLICY IF EXISTS "anon upload animal photos" ON storage.objects;
CREATE POLICY "anon upload animal photos"
  ON storage.objects
  FOR INSERT
  TO anon
  WITH CHECK (bucket_id = 'animal-photos');

-- 允许任何访客读取 animal-photos 桶里的图片
DROP POLICY IF EXISTS "anon read animal photos" ON storage.objects;
CREATE POLICY "anon read animal photos"
  ON storage.objects
  FOR SELECT
  TO anon
  USING (bucket_id = 'animal-photos');

-- ---------- 5. 可选：插入若干示例数据用于演示 ----------
-- 取消下面注释即可插入演示数据
-- INSERT INTO public.reports (ref_id, species, found_at, location, description, contact, photo_url, title, status)
-- VALUES
--   ('WN-2026-0428', '猫 / Cat', now() - interval '3 days', '朝阳区 · 建国门外大街',
--    '瘦弱的橘色幼猫，蜷缩在桥洞角落，对人轻微警惕但接受食物。', '13800000001',
--    'https://images.unsplash.com/photo-1574144611937-0df059b5ef3e?w=800&q=80', '桥下的小橘', 'rescued'),
--   ('WN-2026-0429', '猫 / Cat', now() - interval '2 days', '海淀区 · 中关村南大街',
--    '疑似有人弃养的奶牛猫，毛色干净、亲人，志愿者已多次前往观察。', '13800000002',
--    'https://images.unsplash.com/photo-1561948955-570b270e7c36?w=800&q=80', '停车场的灰色奶牛', 'following'),
--   ('WN-2026-0501', '猫 / Cat', now() - interval '1 days', '丰台区 · 万丰路',
--    '瘦弱三花猫带两只幼崽，住户偶尔投喂，需要尽快TNR绝育。', '13800000003',
--    'https://images.unsplash.com/photo-1592194996308-7b43878e84a6?w=800&q=80', '小区车库的三花', 'pending');

-- ====================================================================
-- 完成。可在 Database → Tables → reports 查看结构，
-- 在 Storage → animal-photos 查看图片桶。
-- ====================================================================
