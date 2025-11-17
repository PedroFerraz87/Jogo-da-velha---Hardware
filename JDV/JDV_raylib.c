#include "raylib.h"
#include <stdlib.h>
#include <stdio.h>

#define WIN_W 600
#define WIN_H 600

// board indices: 0..8
// 0 = empty, 1 = player (X), 2 = cpu (O)
static int board[9];

// winning triples
static const int wins[8][3] = {
    {0,1,2}, {3,4,5}, {6,7,8}, // rows
    {0,3,6}, {1,4,7}, {2,5,8}, // cols
    {0,4,8}, {2,4,6}           // diags
};

// Helper: check if char (1 or 2) has a winning triple
int check_win(int who) {
    for (int i = 0; i < 8; ++i) {
        int a = wins[i][0], b = wins[i][1], c = wins[i][2];
        if (board[a] == who && board[b] == who && board[c] == who) return 1;
    }
    return 0;
}

// Helper: is board full?
int board_full(void) {
    for (int i = 0; i < 9; ++i) if (board[i] == 0) return 0;
    return 1;
}

// CPU helper: try to find index where placing 'who' leads to win, return index or -1
int find_winning_move(int who) {
    for (int i = 0; i < 9; ++i) {
        if (board[i] == 0) {
            board[i] = who;
            int w = check_win(who);
            board[i] = 0;
            if (w) return i;
        }
    }
    return -1;
}

// CPU move following strategy: win, block, center, corners, sides
void cpu_move(void) {
    // 1) try to win
    int idx = find_winning_move(2);
    if (idx != -1) { board[idx] = 2; return; }

    // 2) try to block player
    idx = find_winning_move(1);
    if (idx != -1) { board[idx] = 2; return; }

    // 3) center
    if (board[4] == 0) { board[4] = 2; return; }

    // 4) corners: order 0,2,6,8
    int corners[4] = {0,2,6,8};
    for (int i = 0; i < 4; ++i) {
        if (board[corners[i]] == 0) { board[corners[i]] = 2; return; }
    }

    // 5) sides: 1,3,5,7
    int sides[4] = {1,3,5,7};
    for (int i = 0; i < 4; ++i) {
        if (board[sides[i]] == 0) { board[sides[i]] = 2; return; }
    }
}

// Draw an X inside cell rect (x,y,width,height)
void draw_X(int cx, int cy, int w, int h, int thickness) {
    // draw two diagonal lines
    DrawLine(cx + 10, cy + 10, cx + w - 10, cy + h - 10, WHITE);
    DrawLine(cx + w - 10, cy + 10, cx + 10, cy + h - 10, WHITE);
    // Thicker: draw offset lines
    if (thickness > 1) {
        for (int t = 1; t < thickness; ++t) {
            DrawLine(cx + 10 + t, cy + 10, cx + w - 10 + t, cy + h - 10, WHITE);
            DrawLine(cx + w - 10 + t, cy + 10, cx + 10 + t, cy + h - 10, WHITE);
        }
    }
}

// Draw an O inside cell rect (x,y,width,height)
void draw_O(int cx, int cy, int w, int h, int thickness) {
    int cxCenter = cx + w/2;
    int cyCenter = cy + h/2;
    int radius = (w < h ? w : h)/2 - 12;
    // Draw circle outline with stroke thickness by multiple DrawCircleLines
    for (int t = 0; t < thickness; ++t) {
        DrawCircleLines(cxCenter, cyCenter, radius - t, WHITE);
    }
}

int main(void) {
    InitWindow(WIN_W, WIN_H, "Jogo da Velha - Player vs CPU (raylib)");
    SetTargetFPS(60);

    // init board empty
    for (int i = 0; i < 9; ++i) board[i] = 0;

    float gridX = 50;    // left offset
    float gridY = 50;    // top offset
    float gridW = WIN_W - 2*gridX;
    float gridH = WIN_H - 2*gridY;
    float cellW = gridW / 3.0f;
    float cellH = gridH / 3.0f;

    int state = 0; // 0 = playing, 1 = player won, 2 = cpu won, 3 = draw
    bool playerTurn = true;

    while (!WindowShouldClose()) {
        // Input handling
        if (state == 0 && playerTurn && IsMouseButtonPressed(MOUSE_LEFT_BUTTON)) {
            Vector2 m = GetMousePosition();
            // check if inside grid
            if (m.x >= gridX && m.x <= gridX + gridW && m.y >= gridY && m.y <= gridY + gridH) {
                int col = (int)((m.x - gridX) / cellW);
                int row = (int)((m.y - gridY) / cellH);
                int idx = row * 3 + col;
                if (idx >= 0 && idx < 9 && board[idx] == 0) {
                    board[idx] = 1; // player X
                    // check player win
                    if (check_win(1)) {
                        state = 1;
                    } else if (board_full()) {
                        state = 3;
                    } else {
                        playerTurn = false;
                    }
                }
            }
        }

        // CPU turn
        if (state == 0 && !playerTurn) {
            // small delay to see CPU move (optional)
            // we can wait a few frames
            static int cpuDelay = 0;
            cpuDelay++;
            if (cpuDelay > 8) {
                cpu_move();
                cpuDelay = 0;
                if (check_win(2)) state = 2;
                else if (board_full()) state = 3;
                else playerTurn = true;
            }
        }

        // Drawing
        BeginDrawing();
        ClearBackground(BLACK);

        // Draw grid (white lines)
        // verticals
        DrawLine((int)(gridX + cellW), (int)gridY, (int)(gridX + cellW), (int)(gridY + gridH), WHITE);
        DrawLine((int)(gridX + 2*cellW), (int)gridY, (int)(gridX + 2*cellW), (int)(gridY + gridH), WHITE);
        // horizontals
        DrawLine((int)gridX, (int)(gridY + cellH), (int)(gridX + gridW), (int)(gridY + cellH), WHITE);
        DrawLine((int)gridX, (int)(gridY + 2*cellH), (int)(gridX + gridW), (int)(gridY + 2*cellH), WHITE);

        // draw X and O
        for (int r = 0; r < 3; ++r) {
            for (int c = 0; c < 3; ++c) {
                int i = r*3 + c;
                int cx = (int)(gridX + c*cellW);
                int cy = (int)(gridY + r*cellH);
                int w = (int)cellW;
                int h = (int)cellH;
                if (board[i] == 1) {
                    // draw X - thicker stroke
                    draw_X(cx, cy, w, h, 2);
                } else if (board[i] == 2) {
                    draw_O(cx, cy, w, h, 2);
                }
            }
        }

        // status text
        const int fontSize = 20;
        if (state == 0) {
            if (playerTurn) DrawText("Sua vez (X). Clique numa casa.", 10, 10, fontSize, WHITE);
            else DrawText("CPU pensando...", 10, 10, fontSize, WHITE);
        } else if (state == 1) {
            DrawText("Voce (X) venceu! Pressione R para reiniciar.", 10, 10, fontSize, WHITE);
        } else if (state == 2) {
            DrawText("CPU (O) venceu! Pressione R para reiniciar.", 10, 10, fontSize, WHITE);
        } else if (state == 3) {
            DrawText("Empate! Pressione R para reiniciar.", 10, 10, fontSize, WHITE);
        }

        // restart with R
        if (IsKeyPressed(KEY_R)) {
            for (int i = 0; i < 9; ++i) board[i] = 0;
            state = 0;
            playerTurn = true;
        }

        EndDrawing();
    }

    CloseWindow();
    return 0;
}
