<?php

declare(strict_types=1);

namespace App\Controller\Api;

use DateTimeImmutable;
use Doctrine\DBAL\Connection;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\Routing\Attribute\Route;

#[Route('/api/v1', name: 'api_v1_')]
final class GameSyncController extends AbstractController
{
    public function __construct(private readonly Connection $connection)
    {
    }

    #[Route('/health', name: 'health', methods: ['GET'])]
    public function health(): JsonResponse
    {
        return $this->json([
            'ok' => true,
            'service' => 'rpg-sync-api',
            'time' => (new DateTimeImmutable())->format(DATE_ATOM),
        ]);
    }

    #[Route('/profiles/{profileId<\d+>}', name: 'profile_get', methods: ['GET'])]
    public function getProfile(int $profileId): JsonResponse
    {
        $missing = $this->missingTables();
        if ($missing !== []) {
            return $this->json([
                'ok' => false,
                'error' => 'Missing database tables for sync.',
                'missing_tables' => $missing,
            ], 503);
        }

        $profile = $this->connection->fetchAssociative(
            'SELECT profile_id, user_id, profile_name, level, experience, gold, current_health, max_health, attack, defense, base_speed, last_scene_path, position_x, position_y
             FROM player_profiles
             WHERE profile_id = :profileId',
            ['profileId' => $profileId]
        );

        if ($profile === false) {
            return $this->json([
                'ok' => false,
                'error' => 'Profile not found.',
            ], 404);
        }

        $inventoryRows = $this->connection->fetchAllAssociative(
            'SELECT item_id, quantity FROM player_inventory WHERE profile_id = :profileId',
            ['profileId' => $profileId]
        );

        $inventory = [];
        foreach ($inventoryRows as $row) {
            $itemId = (string) ($row['item_id'] ?? '');
            $quantity = (int) ($row['quantity'] ?? 0);
            if ($itemId !== '' && $quantity > 0) {
                $inventory[$itemId] = $quantity;
            }
        }

        $slotRow = $this->connection->fetchAssociative(
            'SELECT item_id FROM player_action_slots WHERE profile_id = :profileId AND slot_key = :slotKey',
            [
                'profileId' => $profileId,
                'slotKey' => 'R',
            ]
        );

        $questRows = $this->connection->fetchAllAssociative(
            'SELECT quest_id, status, current_progress FROM player_quests WHERE profile_id = :profileId',
            ['profileId' => $profileId]
        );

        $quests = [];
        foreach ($questRows as $row) {
            $questId = (string) ($row['quest_id'] ?? '');
            if ($questId === '') {
                continue;
            }

            $quests[$questId] = [
                'status' => (string) ($row['status'] ?? 'not_started'),
                'current_progress' => (int) ($row['current_progress'] ?? 0),
            ];
        }

        return $this->json([
            'ok' => true,
            'profile' => [
                'profile_id' => (int) $profile['profile_id'],
                'user_id' => (int) $profile['user_id'],
                'profile_name' => (string) $profile['profile_name'],
                'level' => (int) $profile['level'],
                'experience' => (int) $profile['experience'],
                'gold' => (int) $profile['gold'],
                'current_health' => (int) $profile['current_health'],
                'max_health' => (int) $profile['max_health'],
                'attack' => (int) $profile['attack'],
                'defense' => (int) $profile['defense'],
                'base_speed' => (float) $profile['base_speed'],
                'last_scene_path' => $profile['last_scene_path'] !== null ? (string) $profile['last_scene_path'] : null,
                'position_x' => (float) $profile['position_x'],
                'position_y' => (float) $profile['position_y'],
            ],
            'inventory' => $inventory,
            'assigned_action_item' => $slotRow !== false ? (string) ($slotRow['item_id'] ?? '') : '',
            'quests' => $quests,
        ]);
    }

    #[Route('/profiles/{profileId<\d+>}', name: 'profile_sync', methods: ['PUT'])]
    public function syncProfile(int $profileId, Request $request): JsonResponse
    {
        $missing = $this->missingTables();
        if ($missing !== []) {
            return $this->json([
                'ok' => false,
                'error' => 'Missing database tables for sync.',
                'missing_tables' => $missing,
            ], 503);
        }

        $payload = json_decode($request->getContent(), true);
        if (!is_array($payload)) {
            return $this->json([
                'ok' => false,
                'error' => 'Invalid JSON body.',
            ], 400);
        }

        $currentProfile = $this->connection->fetchAssociative(
            'SELECT profile_id, gold, current_health, max_health, attack, defense, base_speed, last_scene_path, position_x, position_y
             FROM player_profiles
             WHERE profile_id = :profileId',
            ['profileId' => $profileId]
        );

        if ($currentProfile === false) {
            return $this->json([
                'ok' => false,
                'error' => 'Profile not found.',
            ], 404);
        }

        $profilePayload = is_array($payload['profile'] ?? null) ? $payload['profile'] : [];

        $this->connection->update(
            'player_profiles',
            [
                'gold' => (int) ($profilePayload['gold'] ?? $currentProfile['gold']),
                'current_health' => (int) ($profilePayload['current_health'] ?? $currentProfile['current_health']),
                'max_health' => (int) ($profilePayload['max_health'] ?? $currentProfile['max_health']),
                'attack' => (int) ($profilePayload['attack'] ?? $currentProfile['attack']),
                'defense' => (int) ($profilePayload['defense'] ?? $currentProfile['defense']),
                'base_speed' => (float) ($profilePayload['base_speed'] ?? $currentProfile['base_speed']),
                'last_scene_path' => $profilePayload['last_scene_path'] ?? $currentProfile['last_scene_path'],
                'position_x' => (float) ($profilePayload['position_x'] ?? $currentProfile['position_x']),
                'position_y' => (float) ($profilePayload['position_y'] ?? $currentProfile['position_y']),
                'updated_at' => (new DateTimeImmutable())->format('Y-m-d H:i:s'),
            ],
            ['profile_id' => $profileId]
        );

        $inventory = is_array($payload['inventory'] ?? null) ? $payload['inventory'] : [];
        $this->connection->delete('player_inventory', ['profile_id' => $profileId]);

        foreach ($inventory as $itemId => $quantityRaw) {
            $itemIdString = (string) $itemId;
            $quantity = (int) $quantityRaw;
            if ($itemIdString === '' || $quantity <= 0) {
                continue;
            }

            $this->connection->insert('player_inventory', [
                'profile_id' => $profileId,
                'item_id' => $itemIdString,
                'quantity' => $quantity,
                'updated_at' => (new DateTimeImmutable())->format('Y-m-d H:i:s'),
            ]);
        }

        $assignedActionItem = (string) ($payload['assigned_action_item'] ?? '');

        $this->connection->delete('player_action_slots', [
            'profile_id' => $profileId,
            'slot_key' => 'R',
        ]);

        if ($assignedActionItem !== '') {
            $this->connection->insert('player_action_slots', [
                'profile_id' => $profileId,
                'slot_key' => 'R',
                'item_id' => $assignedActionItem,
                'updated_at' => (new DateTimeImmutable())->format('Y-m-d H:i:s'),
            ]);
        }

        $quests = is_array($payload['quests'] ?? null) ? $payload['quests'] : [];
        foreach ($quests as $questId => $questData) {
            if (!is_string($questId) || $questId === '' || !is_array($questData)) {
                continue;
            }

            $status = $this->normalizeQuestStatus($questData['status'] ?? 'not_started');
            $currentProgress = max(0, (int) ($questData['current_progress'] ?? 0));

            $updated = $this->connection->update(
                'player_quests',
                [
                    'status' => $status,
                    'current_progress' => $currentProgress,
                    'completed_at' => $status === 'completed'
                        ? (new DateTimeImmutable())->format('Y-m-d H:i:s')
                        : null,
                ],
                [
                    'profile_id' => $profileId,
                    'quest_id' => $questId,
                ]
            );

            if ($updated === 0) {
                $this->connection->insert('player_quests', [
                    'profile_id' => $profileId,
                    'quest_id' => $questId,
                    'status' => $status,
                    'current_progress' => $currentProgress,
                    'started_at' => (new DateTimeImmutable())->format('Y-m-d H:i:s'),
                    'completed_at' => $status === 'completed'
                        ? (new DateTimeImmutable())->format('Y-m-d H:i:s')
                        : null,
                ]);
            }
        }

        return $this->json([
            'ok' => true,
            'profile_id' => $profileId,
        ]);
    }

    /**
     * @return list<string>
     */
    private function missingTables(): array
    {
        $requiredTables = [
            'player_profiles',
            'player_inventory',
            'player_action_slots',
            'player_quests',
        ];

        $existing = array_map('strtolower', $this->connection->createSchemaManager()->listTableNames());
        $missing = [];

        foreach ($requiredTables as $table) {
            if (!in_array(strtolower($table), $existing, true)) {
                $missing[] = $table;
            }
        }

        return $missing;
    }

    private function normalizeQuestStatus(mixed $status): string
    {
        $allowed = ['not_started', 'in_progress', 'completed'];
        $candidate = is_string($status) ? $status : 'not_started';

        if (!in_array($candidate, $allowed, true)) {
            return 'not_started';
        }

        return $candidate;
    }
}
