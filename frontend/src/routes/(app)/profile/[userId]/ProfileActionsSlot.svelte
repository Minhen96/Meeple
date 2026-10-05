<script lang="ts">
	// "···" menu on another user's profile (SCREENS_AND_STATES section 8.2): Block and Report,
	// provided by the social package. Blocking makes this profile a 404, so leave it.
	import { goto } from '$app/navigation';
	import ProfileActionsMenu from '$lib/components/social/ProfileActionsMenu.svelte';

	interface Props {
		userId: string;
		name: string;
	}

	let { userId, name }: Props = $props();
</script>

<ProfileActionsMenu {userId} {name} onBlocked={() => void goto('/')} />
