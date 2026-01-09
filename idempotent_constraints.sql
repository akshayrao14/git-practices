-- Idempotent constraints for tern.opsfeedbackscreening
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'opsfeedbackscreening_candidate_id_fkey') THEN
        ALTER TABLE tern.opsfeedbackscreening ADD CONSTRAINT opsfeedbackscreening_candidate_id_fkey FOREIGN KEY (candidate_id) REFERENCES tern.candidates(zoho_hr_id);
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'opsfeedbackscreening_job_id_fkey') THEN
        ALTER TABLE tern.opsfeedbackscreening ADD CONSTRAINT opsfeedbackscreening_job_id_fkey FOREIGN KEY (job_id) REFERENCES tern.jobopenings(zoho_hr_id);
    END IF;
END $$;

-- Idempotent constraints for tern.employees
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'employees_employee_id_fkey') THEN
        ALTER TABLE tern.employees ADD CONSTRAINT employees_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES tern.candidates(zoho_hr_id) ON UPDATE CASCADE ON DELETE cascade;
    END IF;
END $$;

-- Idempotent constraints for tern.screening_pipelines
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'screening_pipelines_candidate_id_fkey') THEN
        ALTER TABLE tern.screening_pipelines ADD CONSTRAINT screening_pipelines_candidate_id_fkey FOREIGN KEY (candidate_id) REFERENCES tern.candidates(zoho_hr_id) ON UPDATE CASCADE ON DELETE cascade;
    END IF;
END $$;

-- Idempotent constraints for tern.jobscreeningquestionresponses
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'jobscreeningquestionresponses_candidate_id_fkey') THEN
        ALTER TABLE tern.jobscreeningquestionresponses ADD CONSTRAINT jobscreeningquestionresponses_candidate_id_fkey FOREIGN KEY (candidate_id) REFERENCES tern.candidates(zoho_hr_id) ON UPDATE CASCADE ON DELETE cascade;
    END IF;
END $$;

-- Idempotent constraints for tern.screeningreports
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'screeningreports_candidate_id_fkey') THEN
        ALTER TABLE tern.screeningreports ADD CONSTRAINT screeningreports_candidate_id_fkey FOREIGN KEY (candidate_id) REFERENCES tern.candidates(zoho_hr_id) ON UPDATE CASCADE ON DELETE cascade;
    END IF;
END $$;
