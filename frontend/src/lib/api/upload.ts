import { api } from './client';

export interface PresignResponse {
	uploadUrl: string;
	key: string;
	publicUrl: string;
}

export const uploadApi = {
	presign: async (contentType: string): Promise<PresignResponse> => {
		return await api.post<PresignResponse>('/api/v1/upload/presign', { contentType });
	},

	uploadFile: async (uploadUrl: string, file: File): Promise<void> => {
		const res = await fetch(uploadUrl, {
			method: 'PUT',
			body: file,
			headers: {
				'Content-Type': file.type
			}
		});
		if (!res.ok) {
			throw new Error('Failed to upload file to storage');
		}
	},

	direct: async (file: File): Promise<{ publicUrl: string; key: string }> => {
		const formData = new FormData();
		formData.append('file', file);
		return await api.post<{ publicUrl: string; key: string }>('/api/v1/upload', formData);
	}
};
