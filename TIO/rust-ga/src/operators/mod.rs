pub mod crossover;
pub mod mutation;
pub mod selection;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum SelectionMethod {
    Tournament,
    Roulette,
    Ranking,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum CrossoverMethod {
    OnePoint,
    TwoPoint,
    Uniform,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum MutationMethod {
    Reset,
    Inversion,
}

impl SelectionMethod {
    pub fn label(&self) -> &'static str {
        match self {
            SelectionMethod::Tournament => "tournament",
            SelectionMethod::Roulette => "roulette",
            SelectionMethod::Ranking => "ranking",
        }
    }
}

impl CrossoverMethod {
    pub fn label(&self) -> &'static str {
        match self {
            CrossoverMethod::OnePoint => "one_point",
            CrossoverMethod::TwoPoint => "two_point",
            CrossoverMethod::Uniform => "uniform",
        }
    }
}

impl MutationMethod {
    pub fn label(&self) -> &'static str {
        match self {
            MutationMethod::Reset => "reset",
            MutationMethod::Inversion => "inversion",
        }
    }
}
