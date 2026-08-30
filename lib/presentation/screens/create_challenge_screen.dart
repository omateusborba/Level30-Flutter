import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/model/challenge.dart';
import '../../data/service/api_client.dart';
import '../../domain/provider/challenge_provider.dart';

class CreateChallengeScreen extends StatefulWidget {
  const CreateChallengeScreen({super.key});

  @override
  State<CreateChallengeScreen> createState() => _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends State<CreateChallengeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  ChallengeCategory _selectedCategory = ChallengeCategory.study;
  double _xpReward = 300;
  int _totalDays = 30;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onTitleChanged);
  }

  void _onTitleChanged() => setState(() {});

  @override
  void dispose() {
    _titleController.removeListener(_onTitleChanged);
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  bool _submitting = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await context.read<ChallengeProvider>().addChallenge(
            title: _titleController.text.trim(),
            category: _selectedCategory,
            description: _descController.text.trim(),
            xpReward: _xpReward.toInt(),
            totalDays: _totalDays,
          );
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Novo Desafio',
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textSecond),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SliderTheme(
          // valor sempre visível na bolha sobre o thumb
          data: SliderTheme.of(context).copyWith(
            showValueIndicator: ShowValueIndicator.always,
            valueIndicatorColor: AppColors.surface2,
            valueIndicatorTextStyle: const TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          ),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // C3 · atalho para os desafios do programa
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/programa'),
                  icon: const Icon(Icons.workspaces_outline, size: 18),
                  label: const Text('Ver desafios do programa'),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text('ou crie o seu',
                    style:
                        TextStyle(color: AppColors.textSecond, fontSize: 12)),
              ),
              const SizedBox(height: 16),

              // Título
              _SectionLabel('Título do desafio'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Ex: Leitura diária, Exercício matinal…',
                  prefixIcon:
                      Icon(Icons.flag_outlined, color: AppColors.textSecond),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Insira um título';
                  if (v.trim().length < 3) return 'Título muito curto';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Categoria
              _SectionLabel('Categoria'),
              const SizedBox(height: 12),
              _CategorySelector(
                selected: _selectedCategory,
                onChanged: (cat) => setState(() => _selectedCategory = cat),
              ),
              const SizedBox(height: 24),

              // Descrição
              _SectionLabel('Descrição'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descController,
                style: const TextStyle(color: AppColors.textPrimary),
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Descreva o que você vai fazer todos os dias…',
                  alignLabelWithHint: true,
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) {
                  if (v == null || v.trim().isEmpty)
                    return 'Insira uma descrição';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Duração
              _SectionLabel('Duração: $_totalDays dias'),
              Slider(
                value: _totalDays.toDouble(),
                min: 7,
                max: 90,
                divisions: 11,
                activeColor: AppColors.accent,
                inactiveColor: AppColors.surface2,
                label: '$_totalDays dias',
                onChanged: (v) => setState(() => _totalDays = v.toInt()),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('7 dias',
                        style: TextStyle(
                            color: AppColors.textSecond, fontSize: 11)),
                    Text('90 dias',
                        style: TextStyle(
                            color: AppColors.textSecond, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // XP
              _SectionLabel('Recompensa: ${_xpReward.toInt()} XP'),
              Slider(
                value: _xpReward,
                min: 100,
                max: 1000,
                divisions: 18,
                activeColor: AppColors.accent,
                inactiveColor: AppColors.surface2,
                label: '${_xpReward.toInt()} XP',
                onChanged: (v) => setState(() => _xpReward = v),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('100 XP',
                        style: TextStyle(
                            color: AppColors.textSecond, fontSize: 11)),
                    Text('1000 XP',
                        style: TextStyle(
                            color: AppColors.textSecond, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Preview card
              _PreviewCard(
                title: _titleController.text.isEmpty
                    ? 'Título do desafio'
                    : _titleController.text,
                category: _selectedCategory,
                totalDays: _totalDays,
                xpReward: _xpReward.toInt(),
              ),
              const SizedBox(height: 32),

              // Botão criar
              ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.background),
                      )
                    : const Icon(Icons.add_task),
                label: Text(_submitting ? 'Criando…' : 'Criar Desafio'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.poppins(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      );
}

class _CategorySelector extends StatelessWidget {
  final ChallengeCategory selected;
  final ValueChanged<ChallengeCategory> onChanged;

  const _CategorySelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: ChallengeCategory.values.map((cat) {
        final isSelected = cat == selected;
        return GestureDetector(
          onTap: () => onChanged(cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.accent : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.accent : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(cat.icon,
                    size: 15,
                    color: isSelected ? AppColors.accentInk : cat.color),
                const SizedBox(width: 6),
                Text(
                  cat.displayName,
                  style: GoogleFonts.poppins(
                    color:
                        isSelected ? AppColors.accentInk : AppColors.textSecond,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final String title;
  final ChallengeCategory category;
  final int totalDays;
  final int xpReward;

  const _PreviewCard({
    required this.title,
    required this.category,
    required this.totalDays,
    required this.xpReward,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pré-visualização',
          style: GoogleFonts.poppins(
            color: AppColors.textSecond,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border.withAlpha(179)),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: category.color,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(category.emoji,
                                style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: const LinearProgressIndicator(
                            value: 0,
                            backgroundColor: AppColors.surface2,
                            valueColor:
                                AlwaysStoppedAnimation(AppColors.accent),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Dia 0 de $totalDays',
                              style: const TextStyle(
                                  color: AppColors.textSecond, fontSize: 12),
                            ),
                            Text(
                              '$xpReward XP',
                              style: const TextStyle(
                                  color: AppColors.accent, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
