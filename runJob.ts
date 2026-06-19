import { getJob, updateJob } from '@backend/crud/jobs';
import { createClient } from '@supabase/supabase-js';
import { logger, task, tasks } from '@trigger.dev/sdk/v3';
import type { exportProject } from '@trigger/exportProject';
import type { importProject } from '@trigger/importProject';

interface Payload {
  jobId: string;
  projectId?: string;
  token: string;
  publicSupabaseUrl: string;
  publicSupabaseApiKey: string;
  iiifProjectId: string;
  iiifUrl: string;
  vaultTenantPath?: string;
}

const TASK_EXPORT = 'export-project';
const TASK_IMPORT = 'import-project';

export const runJob = task({
  id: 'run-job',

  run: async (payload: Payload) => {
    logger.info('================ RUN-JOB START ================');

    logger.info('RUN-JOB PAYLOAD');
    logger.info(JSON.stringify(payload, null, 2));

    const { publicSupabaseUrl, publicSupabaseApiKey } = payload;

    logger.info(`publicSupabaseUrl=${publicSupabaseUrl}`);
    logger.info(
      `publicSupabaseApiKey present=${!!publicSupabaseApiKey}`
    );

    if (!(publicSupabaseUrl && publicSupabaseApiKey)) {
      logger.error('Invalid Supabase credentials');
      return;
    }

    const { jobId, token, ...rest } = payload;

    logger.info(`jobId=${jobId}`);
    logger.info(`token present=${!!token}`);

    const supabase = createClient(publicSupabaseUrl, publicSupabaseApiKey, {
      global: {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      },
    });

    logger.info('Loading job from database');

    const jobResp = await getJob(supabase, jobId);

    if (jobResp.error) {
      logger.error('getJob failed');
      logger.error(jobResp.error.message);
      return;
    }

    logger.info('JOB DATA');
    logger.info(JSON.stringify(jobResp.data, null, 2));

    let task: 'import-project' | 'export-project' | null;

    if (jobResp.data.job_type === 'EXPORT') {
      task = TASK_EXPORT;
    } else if (jobResp.data.job_type === 'IMPORT') {
      task = TASK_IMPORT;
    } else {
      task = null;
    }

    logger.info(`Selected task=${task}`);

    if (!task) {
      logger.error(
        `Unable to find task for job_type: ${jobResp.data.job_type}`
      );
      return;
    }

    logger.info('Updating job status to PROCESSING');

    await updateJob(supabase, {
      id: jobId,
      job_status: 'PROCESSING',
    });

    logger.info('CHILD TASK PAYLOAD');
    logger.info(
      JSON.stringify(
        {
          tokenPresent: !!token,
          jobId,
          ...rest,
        },
        null,
        2
      )
    );

    try {
      logger.info(`Triggering child task: ${task}`);

      const result = await tasks.triggerAndWait<
        typeof exportProject | typeof importProject
      >(task, {
        token,
        jobId,
        ...rest,
      });

      logger.info('CHILD TASK RESULT');
      logger.info(JSON.stringify(result, null, 2));

      if (result.ok) {
        logger.info('Updating job status to COMPLETE');

        await updateJob(supabase, {
          id: jobId,
          job_status: 'COMPLETE',
        });
      } else {
        logger.error('Child task failed');

        await updateJob(supabase, {
          id: jobId,
          job_status: 'ERROR',
        });
      }
    } catch (error) {
      logger.error('triggerAndWait threw exception');

      if (error instanceof Error) {
        logger.error(error.message);
        logger.error(error.stack || '');
      } else {
        logger.error(String(error));
      }

      await updateJob(supabase, {
        id: jobId,
        job_status: 'ERROR',
      });

      throw error;
    }

    logger.info('================ RUN-JOB END ================');
  },
});