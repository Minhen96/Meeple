import type en from '../common';
import type { Translation } from '../types';

export default {
	appName: 'Meeple',
	save: '保存',
	cancel: '取消',
	delete: '删除',
	confirm: '确认',
	retry: '重试',
	loading: '加载中…',
	loadMore: '加载更多',
	empty: '这里还没有内容',
	offline: '你已离线，部分功能可能无法使用。',
	backOnline: '已恢复网络连接',
	greeting: '你好，{name}！'
} satisfies Translation<typeof en>;
