-- 1. Create Profiles Table (linked to Supabase Auth)
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade primary key,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  full_name text,
  avatar_url text
);

-- 2. Create Categories Table
create table if not exists public.categories (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  name text not null,
  icon text,
  type text check (type in ('income', 'expense')) not null,
  user_id uuid references auth.users on delete cascade
);

-- 3. Create Transactions Table
create table if not exists public.transactions (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  description text not null,
  amount numeric(12, 2) not null,
  date date not null,
  type text check (type in ('income', 'expense')) not null,
  category_id uuid references public.categories on delete set null,
  user_id uuid references auth.users on delete cascade not null
);

-- 4. Enable Row Level Security (RLS)
alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.transactions enable row level security;

-- 5. RLS Policies for Profiles
create policy "Users can view their own profile" 
  on public.profiles for select 
  using (auth.uid() = id);

create policy "Users can update their own profile" 
  on public.profiles for update 
  using (auth.uid() = id);

create policy "Users can insert their own profile" 
  on public.profiles for insert 
  with check (auth.uid() = id);

-- 6. RLS Policies for Categories
create policy "Users can view default or own categories" 
  on public.categories for select 
  using (user_id is null or auth.uid() = user_id);

create policy "Users can insert custom categories" 
  on public.categories for insert 
  with check (auth.uid() = user_id);

create policy "Users can update custom categories" 
  on public.categories for update 
  using (auth.uid() = user_id);

create policy "Users can delete custom categories" 
  on public.categories for delete 
  using (auth.uid() = user_id);

-- 7. RLS Policies for Transactions
create policy "Users can view own transactions" 
  on public.transactions for select 
  using (auth.uid() = user_id);

create policy "Users can insert own transactions" 
  on public.transactions for insert 
  with check (auth.uid() = user_id);

create policy "Users can update own transactions" 
  on public.transactions for update 
  using (auth.uid() = user_id);

create policy "Users can delete own transactions" 
  on public.transactions for delete 
  using (auth.uid() = user_id);

-- 8. Auto-create profile trigger on user signup
create or replace function public.handle_new_user() 
returns trigger as $$
begin
  insert into public.profiles (id, full_name, avatar_url)
  values (new.id, new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'avatar_url');
  return new;
end;
$$ language plpgsql security definer;

create or replace trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();