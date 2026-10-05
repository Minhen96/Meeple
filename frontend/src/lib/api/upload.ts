import { api, ApiRequestError, putToPresignedUrl } from './client';

export interface PresignResponse {
	uploadUrl: string;
	key: string;
	publicUrl: string;
}

/** Backend limit for presigned uploads (413 FILE_TOO_LARGE above this). */
export const MAX_PRESIGNED_UPLOAD_BYTES = 10 * 1024 * 1024;

export const uploadApi = {
	/**
	 * The presigned PUT must then send exactly this Content-Type and a body of
	 * exactly `size` bytes (the browser sets Content-Length from the File).
	 */
	presign: async (contentType: string, size: number): Promise<PresignResponse> => {
		return await api.post<PresignResponse>('/api/v1/upload/presign', { contentType, size });
	},

	uploadFile: (uploadUrl: string, file: File): Promise<void> => putToPresignedUrl(uploadUrl, file),

	/** Presign + PUT in one step. Rejects files over the backend limit up front. */
	presignAndUpload: async (file: File): Promise<{ publicUrl: string; key: string }> => {
		if (file.size > MAX_PRESIGNED_UPLOAD_BYTES) {
			throw new ApiRequestError('FILE_TOO_LARGE', 'File must be 10 MB or smaller', 413);
		}
		const { uploadUrl, key, publicUrl } = await uploadApi.presign(file.type, file.size);
		await putToPresignedUrl(uploadUrl, file);
		return { publicUrl, key };
	},

	direct: async (file: File): Promise<{ publicUrl: string; key: string }> => {
		const formData = new FormData();
		formData.append('file', file);
		return await api.post<{ publicUrl: string; key: string }>('/api/v1/upload', formData);
	}
};
